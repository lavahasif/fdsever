package com.hasif.fdserver.fdserver.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import com.hasif.fdserver.fdserver.CrashRecorder
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.nio.channels.SocketChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedDeque
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

class ProxyVpnService : VpnService() {

    data class TunnelSession(
        val connKey: String,
        val clientIp: String,
        val clientPort: Int,
        val dstIp: String,
        val dstPort: Int,
        @Volatile var proxySocket: Socket?,
        var serverSeq: AtomicLong,
        var clientAck: AtomicLong,
        val proxyConnected: AtomicBoolean = AtomicBoolean(false),
        val proxyConnecting: AtomicBoolean = AtomicBoolean(false),
        val isClosed: AtomicBoolean = AtomicBoolean(false),
        val clientAckedSeq: AtomicLong = AtomicLong(0),
        val clientWindow: AtomicLong = AtomicLong(65535),
        val outboundQueue: ConcurrentLinkedDeque<ByteArray> = ConcurrentLinkedDeque(),
        val isDrainingOutbound: AtomicBoolean = AtomicBoolean(false),
        @Volatile var proxyOutputStream: OutputStream? = null
    )

    companion object {
        const val ACTION_START = "com.hasif.fdserver.START_VPN"
        const val ACTION_STOP = "com.hasif.fdserver.STOP_VPN"

        const val EXTRA_HOST = "extra_host"
        const val EXTRA_PORT = "extra_port"
        const val EXTRA_PROTOCOL = "extra_protocol"
        const val EXTRA_BYPASS_LAN = "extra_bypass_lan"

        private const val TAG = "ProxyVpnService"
        private const val NOTIFICATION_CHANNEL_ID = "fdserver_vpn_channel"
        private const val NOTIFICATION_ID = 2001

        var isRunning = false
            private set

        var targetHost: String = ""
            private set
        var targetPort: Int = 1080
            private set
        var targetProtocol: String = "SOCKS5"
            private set

        val totalBytesIn = AtomicLong(0)
        val totalBytesOut = AtomicLong(0)
        var lastError: String? = null

        var onStateChangeListener: ((Boolean, String?) -> Unit)? = null

        private val logQueue = ConcurrentLinkedDeque<String>()
        private const val MAX_LOG_SIZE = 300
        private val dateFormat = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)

        fun logDiag(msg: String) {
            val timestamp = dateFormat.format(Date())
            val formatted = "[$timestamp] $msg"
            Log.i(TAG, formatted)
            logQueue.addLast(formatted)
            while (logQueue.size > MAX_LOG_SIZE) {
                logQueue.pollFirst()
            }
        }

        fun getRecentLogs(): List<String> {
            return logQueue.toList()
        }

        fun clearLogs() {
            logQueue.clear()
            logDiag("Diagnostic logs cleared.")
        }
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var tunOutputStream: FileOutputStream? = null
    private val tunWriteLock = Any()
    private val isStopping = AtomicBoolean(false)
    private var workerExecutor: ExecutorService? = null

    // Track active connection tunnels (key: "srcIp:srcPort->dstIp:dstPort")
    private val activeSessions = ConcurrentHashMap<String, TunnelSession>()
    // Track in-flight handshakes to prevent duplicate SYN processing
    private val pendingConnections = ConcurrentHashMap.newKeySet<String>()
    // DNS Cache to speed up repeat queries (key: question hash, value: pair(expireTime, responsePayload))
    private val dnsCache = ConcurrentHashMap<String, Pair<Long, ByteArray>>()
    private var bypassLanEnabled = true

    override fun onCreate() {
        super.onCreate()
        try {
            createNotificationChannel()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to create notification channel: ${e.message}", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        val action = intent.action
        if (action == ACTION_STOP) {
            stopVpn()
            return START_NOT_STICKY
        }

        if (action == ACTION_START) {
            targetHost = intent.getStringExtra(EXTRA_HOST) ?: "192.168.43.1"
            targetPort = intent.getIntExtra(EXTRA_PORT, 1080)
            targetProtocol = intent.getStringExtra(EXTRA_PROTOCOL) ?: "SOCKS5"
            val bypassLan = intent.getBooleanExtra(EXTRA_BYPASS_LAN, true)
            bypassLanEnabled = bypassLan

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    try {
                        startForeground(
                            NOTIFICATION_ID,
                            createNotification(),
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                        )
                    } catch (e2: Throwable) {
                        Log.w(TAG, "startForeground with SPECIAL_USE failed, falling back: ${e2.message}")
                        startForeground(NOTIFICATION_ID, createNotification())
                    }
                } else {
                    startForeground(NOTIFICATION_ID, createNotification())
                }
            } catch (e: Throwable) {
                Log.e(TAG, "startForeground error: ${e.message}", e)
                CrashRecorder.record(this, "VPN_FOREGROUND_START_ERROR", "ProxyVpnService", e)
            }

            try {
                startVpn(targetHost, targetPort, targetProtocol, bypassLan)
            } catch (e: Throwable) {
                Log.e(TAG, "startVpn invocation error: ${e.message}", e)
                CrashRecorder.record(this, "VPN_START_INVOCATION_ERROR", "ProxyVpnService", e)
            }
        }

        return START_STICKY
    }

    private fun isLanIp(ip: String): Boolean {
        if (ip == "127.0.0.1" || ip.startsWith("10.0.0.")) return true
        if (ip.startsWith("192.168.") || ip.startsWith("169.254.")) return true
        if (ip.startsWith("10.")) return true
        if (ip.startsWith("172.")) {
            val parts = ip.split(".")
            if (parts.size == 4) {
                val second = parts[1].toIntOrNull() ?: 0
                if (second in 16..31) return true
            }
        }
        return false
    }

    private fun startVpn(host: String, port: Int, protocol: String, bypassLan: Boolean) {
        if (isRunning) return

        isStopping.set(false)
        totalBytesIn.set(0)
        totalBytesOut.set(0)
        lastError = null

        logDiag("=== VPN START REQUESTED ===")
        logDiag("Target: $host:$port ($protocol) | BypassLAN: $bypassLan")

        workerExecutor = Executors.newCachedThreadPool()

        workerExecutor?.execute {
            try {
                val builder = Builder()
                    .setSession("FDServer Proxy Diverter")
                    .addAddress("10.0.0.2", 24)
                    .addAddress("fd00::1", 128)
                    .addRoute("::", 0)
                    .addDnsServer("8.8.8.8")
                    .addDnsServer("1.1.1.1")
                    .setMtu(1500)

                if (bypassLan) {
                    logDiag("Configuring VpnService.Builder (Public IPv4 routes, Hotspot/LAN bypassed)...")
                    val publicRanges = listOf(
                        Pair("1.0.0.0", 8),
                        Pair("2.0.0.0", 7),
                        Pair("4.0.0.0", 6),
                        Pair("8.0.0.0", 7),
                        Pair("11.0.0.0", 8),
                        Pair("12.0.0.0", 6),
                        Pair("16.0.0.0", 4),
                        Pair("32.0.0.0", 3),
                        Pair("64.0.0.0", 2),
                        Pair("128.0.0.0", 3),
                        Pair("160.0.0.0", 5),
                        Pair("168.0.0.0", 6),
                        Pair("170.0.0.0", 7),
                        Pair("172.0.0.0", 12),
                        Pair("172.32.0.0", 11),
                        Pair("172.64.0.0", 10),
                        Pair("172.128.0.0", 9),
                        Pair("173.0.0.0", 8),
                        Pair("174.0.0.0", 7),
                        Pair("176.0.0.0", 4),
                        Pair("192.0.0.0", 9),
                        Pair("192.128.0.0", 11),
                        Pair("192.160.0.0", 13),
                        Pair("192.169.0.0", 16),
                        Pair("192.170.0.0", 15),
                        Pair("192.172.0.0", 14),
                        Pair("192.176.0.0", 12),
                        Pair("192.192.0.0", 10),
                        Pair("193.0.0.0", 8),
                        Pair("194.0.0.0", 7),
                        Pair("196.0.0.0", 6),
                        Pair("200.0.0.0", 5),
                        Pair("208.0.0.0", 4)
                    )
                    for (r in publicRanges) {
                        builder.addRoute(r.first, r.second)
                    }
                } else {
                    logDiag("Configuring VpnService.Builder (All IPv4 0.0.0.0/0)...")
                    builder.addRoute("0.0.0.0", 0)
                }

                // Exclude FDServer itself so its own connection to the proxy doesn't loop back!
                try {
                    builder.addDisallowedApplication(packageName)
                    logDiag("Excluded $packageName from VPN tunnel.")
                } catch (e: Exception) {
                    logDiag("Warning: addDisallowedApplication failed: ${e.message}")
                }

                vpnInterface = builder.establish()
                if (vpnInterface == null) {
                    lastError = "Failed to establish VPN TUN interface. VPN permission may have been cancelled or another VPN is running."
                    logDiag("[ERROR] $lastError")
                    CrashRecorder.record(this@ProxyVpnService, "VPN_ESTABLISH_NULL", "ProxyVpnService", Exception(lastError))
                    stopVpn()
                    return@execute
                }

                isRunning = true
                onStateChangeListener?.invoke(true, null)
                logDiag("[OK] VPN TUN established! FD=${vpnInterface?.fd}. Diverting all apps to $host:$port via $protocol")

                // Start packet processing loop
                runTunLoop(vpnInterface!!)

            } catch (e: Exception) {
                val err = "Error starting VPN: ${e.message}"
                logDiag("[EXCEPTION] $err")
                lastError = e.message
                CrashRecorder.record(this@ProxyVpnService, "VPN_TUN_EXCEPTION", "ProxyVpnService", e)
                stopVpn()
            }
        }
    }

    private fun runTunLoop(descriptor: ParcelFileDescriptor) {
        val inputStream = FileInputStream(descriptor.fileDescriptor)
        tunOutputStream = FileOutputStream(descriptor.fileDescriptor)
        val packet = ByteArray(32768)
        logDiag("TUN loop started. Listening for Android app IP packets...")

        while (!isStopping.get()) {
            try {
                val length = inputStream.read(packet)
                if (length <= 0) {
                    Thread.sleep(10)
                    continue
                }

                totalBytesOut.addAndGet(length.toLong())

                // Process IP packet header
                processIpPacket(packet, length)

            } catch (e: Exception) {
                if (!isStopping.get()) {
                    logDiag("[TUN-LOOP-ERR] Exception reading from TUN: ${e.message}")
                }
                break
            }
        }
    }

    private fun processIpPacket(packet: ByteArray, length: Int) {
        if (length < 20) return
        val version = (packet[0].toInt() shr 4) and 0x0F
        if (version == 6) {
            // Drop IPv6 traffic cleanly so Android and apps immediately fall back to IPv4
            return
        }
        if (version != 4) return // Only IPv4 for proxy redirect

        val protocol = packet[9].toInt() and 0xFF
        val headerLen = (packet[0].toInt() and 0x0F) * 4

        val srcIp = "${packet[12].toInt() and 0xFF}.${packet[13].toInt() and 0xFF}.${packet[14].toInt() and 0xFF}.${packet[15].toInt() and 0xFF}"
        val dstIp = "${packet[16].toInt() and 0xFF}.${packet[17].toInt() and 0xFF}.${packet[18].toInt() and 0xFF}.${packet[19].toInt() and 0xFF}"

        // Skip internal loopback, target proxy host itself, and LAN subnets if bypassLan is active
        if (dstIp.startsWith("10.0.0.") || dstIp == "127.0.0.1") return
        if (dstIp == targetHost) return
        if (bypassLanEnabled && isLanIp(dstIp)) return

        // Handle UDP (Protocol 17)
        if (protocol == 17 && length >= headerLen + 8) {
            val srcPort = ((packet[headerLen].toInt() and 0xFF) shl 8) or (packet[headerLen + 1].toInt() and 0xFF)
            val dstPort = ((packet[headerLen + 2].toInt() and 0xFF) shl 8) or (packet[headerLen + 3].toInt() and 0xFF)
            if (dstPort == 53) {
                workerExecutor?.execute {
                    handleDnsQuery(srcIp, srcPort, dstIp, dstPort, packet, headerLen, length)
                }
                return
            } else {
                // Reject non-DNS UDP (e.g. QUIC port 443) with ICMP Port Unreachable immediately
                // so Chrome and Android apps fail-fast and switch to TCP immediately without a 10s stall!
                sendIcmpPortUnreachable(packet, length)
                return
            }
        }

        // Handle TCP (Protocol 6)
        if (protocol == 6 && length >= headerLen + 20) {
            val srcPort = ((packet[headerLen].toInt() and 0xFF) shl 8) or (packet[headerLen + 1].toInt() and 0xFF)
            val dstPort = ((packet[headerLen + 2].toInt() and 0xFF) shl 8) or (packet[headerLen + 3].toInt() and 0xFF)
            val flags = packet[headerLen + 13].toInt() and 0xFF
            val isSyn = (flags and 0x02) != 0
            val isFin = (flags and 0x01) != 0
            val isRst = (flags and 0x04) != 0

            val connKey = "$srcIp:$srcPort->$dstIp:$dstPort"

            // New Connection Request: TCP SYN
            if (isSyn) {
                if (activeSessions.containsKey(connKey) || !pendingConnections.add(connKey)) {
                    return // Duplicate SYN; already in progress or connected
                }

                val clientIsn = ((packet[headerLen + 4].toLong() and 0xFF) shl 24) or
                                ((packet[headerLen + 5].toLong() and 0xFF) shl 16) or
                                ((packet[headerLen + 6].toLong() and 0xFF) shl 8) or
                                (packet[headerLen + 7].toLong() and 0xFF)

                logDiag("[TUN-IN] TCP SYN detected: $connKey (ISN=$clientIsn)")

                // DEFERRED PROXY CONNECTION: Immediately send SYN-ACK to the client app
                // WITHOUT connecting to the proxy yet. The proxy connection will happen
                // when the client sends its first data packet (e.g., TLS ClientHello).
                // This eliminates the EveryProxy 10s idle timeout race condition.
                val initialServerSeq = (System.currentTimeMillis() and 0x7FFFFFFFL)
                val initialClientAck = (clientIsn + 1) and 0xFFFFFFFFL

                val session = TunnelSession(
                    connKey = connKey,
                    clientIp = srcIp,
                    clientPort = srcPort,
                    dstIp = dstIp,
                    dstPort = dstPort,
                    proxySocket = null,
                    serverSeq = AtomicLong(initialServerSeq),
                    clientAck = AtomicLong(initialClientAck)
                )
                activeSessions[connKey] = session

                sendTcpPacket(
                    srcIp = dstIp,
                    srcPort = dstPort,
                    dstIp = srcIp,
                    dstPort = srcPort,
                    seq = initialServerSeq,
                    ack = initialClientAck,
                    flags = 0x12, // SYN | ACK
                    payload = null
                )
                session.serverSeq.updateAndGet { (it + 1) and 0xFFFFFFFFL }
                logDiag("[TCP-SYN-ACK] Sent SYN-ACK for $connKey! Proxy deferred until client data.")

                pendingConnections.remove(connKey)
                return
            }

            // Existing Active Connection: Data or Close
            val session = activeSessions[connKey]
            if (session != null) {
                // Update client's ACKed server sequence and advertised window from every incoming TCP packet
                val clientAckNumber = ((packet[headerLen + 8].toLong() and 0xFF) shl 24) or
                                      ((packet[headerLen + 9].toLong() and 0xFF) shl 16) or
                                      ((packet[headerLen + 10].toLong() and 0xFF) shl 8) or
                                      (packet[headerLen + 11].toLong() and 0xFF)
                val clientWindowSize = ((packet[headerLen + 14].toLong() and 0xFF) shl 8) or
                                       (packet[headerLen + 15].toLong() and 0xFF)
                session.clientAckedSeq.set(clientAckNumber)
                session.clientWindow.set(clientWindowSize)

                val tcpHeaderLen = ((packet[headerLen + 12].toInt() shr 4) and 0x0F) * 4
                val payloadOffset = headerLen + tcpHeaderLen
                val payloadLen = length - payloadOffset

                if (payloadLen > 0 || isFin || isRst) {
                    logDiag("[TUN-IN-PKT] $connKey len=$length payLen=$payloadLen flags=0x${flags.toString(16)}")
                }

                if (isFin || isRst) {
                    val clientSeq = ((packet[headerLen + 4].toLong() and 0xFF) shl 24) or
                                    ((packet[headerLen + 5].toLong() and 0xFF) shl 16) or
                                    ((packet[headerLen + 6].toLong() and 0xFF) shl 8) or
                                    (packet[headerLen + 7].toLong() and 0xFF)

                    // If packet contains trailing payload with FIN, enqueue and drain it before closing
                    if (isFin && payloadLen > 0) {
                        val trailingPayload = packet.copyOfRange(payloadOffset, length)
                        session.outboundQueue.addLast(trailingPayload)
                        drainOutbound(session)
                    }

                    logDiag("[TCP-CLOSE] Client sent ${if (isFin) "FIN" else "RST"} for $connKey. Closing.")
                    session.isClosed.set(true)
                    activeSessions.remove(connKey)

                    if (isFin) {
                        // ACK the client's FIN (FIN consumes 1 sequence number) so client socket doesn't hang
                        val finAck = (clientSeq + maxOf(0, payloadLen) + 1) and 0xFFFFFFFFL
                        sendTcpPacket(
                            srcIp = dstIp,
                            srcPort = dstPort,
                            dstIp = srcIp,
                            dstPort = srcPort,
                            seq = session.serverSeq.get(),
                            ack = finAck,
                            flags = 0x11, // FIN | ACK
                            payload = null
                        )
                    }

                    try {
                        session.proxySocket?.close()
                    } catch (_: Exception) {}
                    return
                }

                if (payloadLen > 0) {
                    val payload = packet.copyOfRange(payloadOffset, length)
                    val clientSeq = ((packet[headerLen + 4].toLong() and 0xFF) shl 24) or
                                    ((packet[headerLen + 5].toLong() and 0xFF) shl 16) or
                                    ((packet[headerLen + 6].toLong() and 0xFF) shl 8) or
                                    (packet[headerLen + 7].toLong() and 0xFF)

                    val expectedAck = session.clientAck.get()
                    val diff = ((clientSeq + payloadLen - expectedAck).toInt())
                    logDiag("[TCP-CHECK] $connKey seq=$clientSeq expAck=$expectedAck diff=$diff payLen=$payloadLen")

                    // TCP Retransmission detection: if client is sending bytes we already acknowledged,
                    // do NOT send duplicate bytes to proxy (which corrupts TLS/HTTP streams).
                    if (diff <= 0) {
                        logDiag("[TCP-RETRANS-DROP] $connKey seq=$clientSeq payLen=$payloadLen diff=$diff expAck=$expectedAck")
                        // Entire packet is duplicate; just re-ACK expected sequence
                        sendTcpPacket(
                            srcIp = dstIp,
                            srcPort = dstPort,
                            dstIp = srcIp,
                            dstPort = srcPort,
                            seq = session.serverSeq.get(),
                            ack = expectedAck,
                            flags = 0x10, // ACK
                            payload = null
                        )
                        return
                    }

                    // Gap detection: if clientSeq is ahead of expected contiguous sequence,
                    // do NOT advance clientAck beyond the gap! Send duplicate ACK so client retransmits.
                    if (clientSeq > expectedAck) {
                        logDiag("[TCP-GAP-DROP] $connKey seq=$clientSeq > expAck=$expectedAck payLen=$payloadLen")
                        sendTcpPacket(
                            srcIp = dstIp,
                            srcPort = dstPort,
                            dstIp = srcIp,
                            dstPort = srcPort,
                            seq = session.serverSeq.get(),
                            ack = expectedAck,
                            flags = 0x10, // ACK
                            payload = null
                        )
                        return
                    }

                    // Handle partial retransmissions: skip already-received prefix
                    val skipBytes = maxOf(0, (expectedAck - clientSeq).toInt())
                    if (skipBytes >= payloadLen) {
                        return
                    }
                    val effectivePayload = if (skipBytes > 0) {
                        payload.copyOfRange(skipBytes, payloadLen)
                    } else {
                        payload
                    }

                    val nextAck = (clientSeq + payloadLen) and 0xFFFFFFFFL
                    session.clientAck.set(nextAck)

                    // Send ACK immediately so the client app advances its TCP window
                    sendTcpPacket(
                        srcIp = dstIp,
                        srcPort = dstPort,
                        dstIp = srcIp,
                        dstPort = srcPort,
                        seq = session.serverSeq.get(),
                        ack = nextAck,
                        flags = 0x10, // ACK
                        payload = null
                    )

                    // Enqueue payload into the strictly serialized in-order FIFO queue
                    session.outboundQueue.addLast(effectivePayload)

                    if (session.proxyConnected.get()) {
                        // Proxy is connected — drain queue in strict FIFO order
                        drainOutbound(session)
                    } else {
                        // Proxy NOT yet connected — payload stays in queue
                        logDiag("[TCP-BUFFER] Buffered ${effectivePayload.size} bytes for $connKey (proxy connecting...)")

                        // Trigger proxy connection on first data packet
                        if (session.proxyConnecting.compareAndSet(false, true)) {
                            logDiag("[DEFERRED] First data arrived for $connKey! Connecting to proxy now...")
                            workerExecutor?.execute {
                                connectProxyAndRelay(session)
                            }
                        }
                    }
                }
            } else if (!isRst) {
                // Connection is closed or unknown: reply with RST so client closes immediately
                val clientSeq = ((packet[headerLen + 4].toLong() and 0xFF) shl 24) or
                                ((packet[headerLen + 5].toLong() and 0xFF) shl 16) or
                                ((packet[headerLen + 6].toLong() and 0xFF) shl 8) or
                                (packet[headerLen + 7].toLong() and 0xFF)
                val tcpHeaderLen = ((packet[headerLen + 12].toInt() shr 4) and 0x0F) * 4
                val payloadLen = maxOf(0, length - (headerLen + tcpHeaderLen))
                val ackNumber = (clientSeq + maxOf(1, payloadLen.toLong())) and 0xFFFFFFFFL
                sendTcpPacket(
                    srcIp = dstIp,
                    srcPort = dstPort,
                    dstIp = srcIp,
                    dstPort = srcPort,
                    seq = 0,
                    ack = ackNumber,
                    flags = 0x14, // RST | ACK
                    payload = null
                )
            }
        }
    }

    /**
     * Deferred Proxy Connection: Called when the FIRST data packet arrives from the client.
     * Connects to EveryProxy, performs SOCKS5/HTTP handshake, flushes buffered data,
     * and starts the bidirectional relay loop.
     *
     * This eliminates EveryProxy's idle timeout race condition because data is flushed
     * to the proxy immediately after the handshake — zero idle time.
     */
    private fun connectProxyAndRelay(session: TunnelSession) {
        var proxySocket: Socket? = null
        try {
            logDiag("[TUNNEL] Opening socket to target proxy $targetHost:$targetPort for destination ${session.dstIp}:${session.dstPort}...")

            // Use standard java.net.Socket with ephemeral bind so Linux allocates a real socket FD before protect()!
            // Unlike SocketChannel's SocketAdaptor, standard Socket does NOT share a monitor lock between InputStream and OutputStream!
            val proxySock = Socket()
            proxySock.bind(null)
            proxySock.soTimeout = 15000 // 15s timeout for handshake

            // CRITICAL: Protect socket so its packets bypass the VPN TUN and go straight to Wi-Fi/Hotspot!
            val protectOk = protect(proxySock)
            logDiag("[SOCKET-PROTECT] protect(socket) result: $protectOk")
            if (!protectOk) {
                logDiag("[TUNNEL-WARN] protect(socket) returned false! Traffic may loop back.")
            }

            proxySock.connect(InetSocketAddress(targetHost, targetPort), 5000)
            proxySock.tcpNoDelay = true
            proxySock.keepAlive = true
            proxySocket = proxySock
            logDiag("[TUNNEL] Connected to $targetHost:$targetPort. Starting $targetProtocol handshake for ${session.dstIp}:${session.dstPort}...")

            val inStream = proxySock.getInputStream()
            val outStream = proxySock.getOutputStream()
            session.proxyOutputStream = outStream

            // Perform proxy handshake
            val connected = if (targetProtocol.equals("HTTP", ignoreCase = true)) {
                handshakeHttpConnect(outStream, inStream, session.dstIp, session.dstPort)
            } else {
                handshakeSocks5(outStream, inStream, session.dstIp, session.dstPort)
            }

            if (!connected) {
                logDiag("[TUNNEL-ERR] Handshake failed for ${session.connKey}. Sending RST to client.")
                // Send RST to client so it retries immediately
                sendTcpPacket(
                    srcIp = session.dstIp,
                    srcPort = session.dstPort,
                    dstIp = session.clientIp,
                    dstPort = session.clientPort,
                    seq = session.serverSeq.get(),
                    ack = session.clientAck.get(),
                    flags = 0x04, // RST
                    payload = null
                )
                activeSessions.remove(session.connKey)
                proxySocket.close()
                return
            }

            // Mark proxy as connected and store the socket
            session.proxySocket = proxySocket
            session.proxyConnected.set(true)

            logDiag("[TUNNEL-OK] Proxy tunnel LIVE for ${session.connKey}. Starting bidirectional relay...")

            // Synchronously flush initial buffered client payload (e.g. HTTP GET / TLS Client Hello)
            // directly onto outStream so the proxy forwards it to the remote server immediately!
            while (!session.isClosed.get() && !proxySocket.isClosed) {
                val chunk = session.outboundQueue.pollFirst() ?: break
                synchronized(outStream) {
                    outStream.write(chunk)
                    outStream.flush()
                }
                logDiag("[TCP-DATA-OUT] Flushed ${chunk.size} bytes (initial buffer) to proxy for ${session.connKey}")
            }

            // Drain any data buffered prior to or during handshake in strict FIFO order
            drainOutbound(session)

            // Reset socket timeout for long-lived bidirectional streaming
            proxySocket.soTimeout = 0

            // Pipe incoming responses from Proxy -> Client App via TUN
            val buffer = ByteArray(32768)
            var readLen = 0
            while (!isStopping.get() && !session.isClosed.get() && !proxySocket.isClosed && inStream.read(buffer).also { readLen = it } != -1) {
                totalBytesIn.addAndGet(readLen.toLong())
                val data = buffer.copyOfRange(0, readLen)

                // Chunk into TCP MSS segments (1360 bytes max) so MTU is never exceeded
                var offset = 0
                var chunkCount = 0
                while (offset < data.size && !session.isClosed.get()) {
                    val chunkSize = minOf(1360, data.size - offset)
                    val chunk = data.copyOfRange(offset, offset + chunkSize)
                    val currentSeq = session.serverSeq.get()
                    val currentAck = session.clientAck.get()

                    val isLastChunk = (offset + chunkSize >= data.size)
                    sendTcpPacket(
                        srcIp = session.dstIp,
                        srcPort = session.dstPort,
                        dstIp = session.clientIp,
                        dstPort = session.clientPort,
                        seq = currentSeq,
                        ack = currentAck,
                        flags = if (isLastChunk) 0x18 else 0x10, // PSH on last segment of read buffer
                        payload = chunk
                    )
                    session.serverSeq.updateAndGet { (it + chunkSize) and 0xFFFFFFFFL }
                    offset += chunkSize
                    chunkCount++

                    // Pacing: pause 3ms every 3 chunks (~4 KB) so Android kernel & Chrome user-space
                    // socket buffer drain and never drop packets due to buffer overflow!
                    if (chunkCount % 3 == 0 && offset < data.size) {
                        try {
                            Thread.sleep(3)
                        } catch (_: Exception) {}
                    }
                }
                logDiag("[TCP-DATA-IN] Relayed $readLen bytes from proxy -> app (${session.connKey})")
            }

            if (!session.isClosed.getAndSet(true)) {
                activeSessions.remove(session.connKey)
                // Server closed connection: send FIN-ACK to client app so it completes TCP teardown
                val currentSeq = session.serverSeq.get()
                val currentAck = session.clientAck.get()
                sendTcpPacket(
                    srcIp = session.dstIp,
                    srcPort = session.dstPort,
                    dstIp = session.clientIp,
                    dstPort = session.clientPort,
                    seq = currentSeq,
                    ack = currentAck,
                    flags = 0x11, // FIN | ACK
                    payload = null
                )
                session.serverSeq.updateAndGet { (it + 1) and 0xFFFFFFFFL }
                logDiag("[TCP-FIN] Sent FIN-ACK to client app for ${session.connKey}")

                try {
                    proxySocket.close()
                } catch (_: Exception) {}
            }

        } catch (e: Exception) {
            if (!session.isClosed.get() && proxySocket?.isClosed != true) {
                logDiag("[TUNNEL-ERR] ${session.connKey} error: ${e.javaClass.simpleName} - ${e.message}")
            }
        } finally {
            session.isClosed.set(true)
            try {
                proxySocket?.close()
            } catch (_: Exception) {}
            activeSessions.remove(session.connKey)
        }
    }

    /**
     * Drains the serialized FIFO outbound queue to the proxy socket.
     * Guaranteed to run at most one active worker per session at a time,
     * ensuring 100% strict in-order packet delivery without TLS stream corruption.
     */
    private fun drainOutbound(session: TunnelSession) {
        val qSize = session.outboundQueue.size
        if (!session.proxyConnected.get()) {
            logDiag("[DRAIN-SKIP] Not connected for ${session.connKey} (qSize=$qSize)")
            return
        }
        if (session.isClosed.get()) return
        if (!session.isDrainingOutbound.compareAndSet(false, true)) {
            logDiag("[DRAIN-SKIP] Already draining for ${session.connKey} (qSize=$qSize)")
            return
        }

        workerExecutor?.execute {
            try {
                val sock = session.proxySocket
                if (sock == null || sock.isClosed || sock.isOutputShutdown) {
                    logDiag("[DRAIN-ERR] Socket closed or null for ${session.connKey}")
                    return@execute
                }
                val out = session.proxyOutputStream ?: sock.getOutputStream()
                while (!session.isClosed.get() && !sock.isClosed && !sock.isOutputShutdown) {
                    val chunk = session.outboundQueue.pollFirst() ?: break
                    synchronized(out) {
                        out.write(chunk)
                        out.flush()
                    }
                    logDiag("[TCP-DATA-OUT] Forwarded ${chunk.size} bytes client -> proxy (${session.connKey})")
                }
            } catch (e: Exception) {
                if (!session.isClosed.get() && session.proxySocket?.isClosed != true) {
                    logDiag("[TCP-DATA-ERR] Failed sending client payload to proxy (${session.connKey}): ${e.message}")
                }
            } finally {
                session.isDrainingOutbound.set(false)
                if (!session.outboundQueue.isEmpty() && !session.isClosed.get() && session.proxySocket?.isClosed != true) {
                    drainOutbound(session)
                }
            }
        }
    }

    private fun handleDnsQuery(
        clientIp: String,
        clientPort: Int,
        dstIp: String,
        dstPort: Int,
        packet: ByteArray,
        headerLen: Int,
        length: Int
    ) {
        try {
            val queryPayload = packet.copyOfRange(headerLen + 8, length)
            if (queryPayload.size < 12) return // Invalid DNS header

            val txId0 = queryPayload[0]
            val txId1 = queryPayload[1]

            // Inspect question QTYPE to fast-synthesize empty NOERROR responses for IPv6 (AAAA=28) and HTTPS/SVCB (65).
            // This prevents Chrome and apps from stalling on IPv6 timeouts or trying HTTP/3 QUIC over IPv6.
            var qnameIdx = 12
            while (qnameIdx < queryPayload.size && queryPayload[qnameIdx] != 0.toByte()) {
                val labelLen = queryPayload[qnameIdx].toInt() and 0xFF
                qnameIdx += 1 + labelLen
            }
            if (qnameIdx < queryPayload.size && queryPayload[qnameIdx] == 0.toByte()) {
                qnameIdx++ // Skip terminating 0-byte
                if (qnameIdx + 1 < queryPayload.size) {
                    val qtype = ((queryPayload[qnameIdx].toInt() and 0xFF) shl 8) or (queryPayload[qnameIdx + 1].toInt() and 0xFF)
                    if (qtype == 28 || qtype == 65) {
                        // Synthesize NOERROR with 0 answers (NODATA)
                        val resp = queryPayload.clone()
                        resp[2] = 0x81.toByte() // Response, Opcode=0, RD=1
                        resp[3] = 0x80.toByte() // RA=1, RCODE=0 (NoError)
                        resp[4] = 0x00.toByte() // QDCOUNT = 1
                        resp[5] = 0x01.toByte()
                        resp[6] = 0x00.toByte() // ANCOUNT = 0
                        resp[7] = 0x00.toByte()
                        resp[8] = 0x00.toByte() // NSCOUNT = 0
                        resp[9] = 0x00.toByte()
                        resp[10] = 0x00.toByte() // ARCOUNT = 0
                        resp[11] = 0x00.toByte()

                        sendUdpPacket(
                            srcIp = dstIp,
                            srcPort = dstPort,
                            dstIp = clientIp,
                            dstPort = clientPort,
                            payload = resp
                        )
                        return
                    }
                }
            }

            // Cache key based on query question (excluding txId bytes 0 and 1)
            val cacheKey = "${dstIp}_" + queryPayload.copyOfRange(2, queryPayload.size).contentHashCode()
            val now = System.currentTimeMillis()
            val cached = dnsCache[cacheKey]
            if (cached != null && cached.first > now) {
                val resp = cached.second.clone()
                resp[0] = txId0
                resp[1] = txId1
                sendUdpPacket(
                    srcIp = dstIp,
                    srcPort = dstPort,
                    dstIp = clientIp,
                    dstPort = clientPort,
                    payload = resp
                )
                logDiag("[DNS-CACHE] Hit for $dstIp ($length bytes) -> 0ms")
                return
            }

            // Resolve via TCP through Proxy first (Phone B Hotspot blocks direct UDP to internet)
            var responseData = resolveDnsViaProxy(dstIp, dstPort, queryPayload)

            // Fallback to direct UDP if proxy DNS connection failed
            if (responseData == null) {
                responseData = resolveDnsDirectUdp(dstIp, dstPort, queryPayload)
            }

            if (responseData != null) {
                // Cache response for 60 seconds
                dnsCache[cacheKey] = Pair(now + 60000L, responseData)

                sendUdpPacket(
                    srcIp = dstIp,
                    srcPort = dstPort,
                    dstIp = clientIp,
                    dstPort = clientPort,
                    payload = responseData
                )
                logDiag("[DNS-RESOLVED] DNS resolved via proxy ($length bytes -> ${responseData.size} bytes) from $dstIp")
            } else {
                logDiag("[DNS-ERR] Could not resolve DNS query via $dstIp (proxy & direct both failed)")
            }
        } catch (e: Exception) {
            logDiag("[DNS-ERR] DNS handler exception: ${e.message}")
        }
    }

    private fun resolveDnsViaProxy(
        targetDnsIp: String,
        targetDnsPort: Int,
        queryPayload: ByteArray
    ): ByteArray? {
        var proxySock: Socket? = null
        try {
            proxySock = Socket()
            proxySock.bind(null)
            proxySock.soTimeout = 4000
            val protectOk = protect(proxySock)
            if (!protectOk) {
                logDiag("[DNS-WARN] protect(dnsSocket) returned false!")
            }

            proxySock.connect(InetSocketAddress(targetHost, targetPort), 3000)
            proxySock.tcpNoDelay = true

            val inStream = proxySock.getInputStream()
            val outStream = proxySock.getOutputStream()

            val connected = if (targetProtocol.equals("HTTP", ignoreCase = true)) {
                handshakeHttpConnect(outStream, inStream, targetDnsIp, targetDnsPort)
            } else {
                handshakeSocks5(outStream, inStream, targetDnsIp, targetDnsPort)
            }

            if (!connected) return null

            // DNS over TCP (RFC 1035): 2-byte big-endian length prefix + DNS query payload
            val queryLen = queryPayload.size
            val req = ByteArray(2 + queryLen)
            req[0] = ((queryLen shr 8) and 0xFF).toByte()
            req[1] = (queryLen and 0xFF).toByte()
            System.arraycopy(queryPayload, 0, req, 2, queryLen)

            outStream.write(req)
            outStream.flush()

            // Read 2-byte response length prefix
            val lenBuf = ByteArray(2)
            readExact(inStream, lenBuf, 0, 2)
            val respLen = ((lenBuf[0].toInt() and 0xFF) shl 8) or (lenBuf[1].toInt() and 0xFF)
            if (respLen <= 0 || respLen > 4096) return null

            val respBuf = ByteArray(respLen)
            readExact(inStream, respBuf, 0, respLen)
            return respBuf
        } catch (e: Exception) {
            logDiag("[DNS-PROXY-ERR] Failed resolving DNS via proxy to $targetDnsIp:$targetDnsPort: ${e.message}")
            return null
        } finally {
            try {
                proxySock?.close()
            } catch (_: Exception) {}
        }
    }

    private fun resolveDnsDirectUdp(
        dstIp: String,
        dstPort: Int,
        queryPayload: ByteArray
    ): ByteArray? {
        var dnsSocket: DatagramSocket? = null
        try {
            dnsSocket = DatagramSocket()
            protect(dnsSocket)
            dnsSocket.soTimeout = 1000
            val sendPacket = DatagramPacket(queryPayload, queryPayload.size, InetAddress.getByName(dstIp), dstPort)
            dnsSocket.send(sendPacket)

            val receiveBuf = ByteArray(2048)
            val receivePacket = DatagramPacket(receiveBuf, receiveBuf.size)
            dnsSocket.receive(receivePacket)
            return receiveBuf.copyOfRange(0, receivePacket.length)
        } catch (e: Exception) {
            return null
        } finally {
            dnsSocket?.close()
        }
    }

    private fun sendTcpPacket(
        srcIp: String,
        srcPort: Int,
        dstIp: String,
        dstPort: Int,
        seq: Long,
        ack: Long,
        flags: Int,
        payload: ByteArray?
    ) {
        val payloadLen = payload?.size ?: 0
        val isSyn = (flags and 0x02) != 0
        // When SYN is set, include MSS (4B) + Window Scale (3B) + SACK Permitted (2B) + NOPs (3B) = 12 bytes
        val tcpOptionsLen = if (isSyn) 12 else 0
        val tcpHeaderLen = 20 + tcpOptionsLen
        val totalLen = 20 + tcpHeaderLen + payloadLen
        val packet = ByteArray(totalLen)

        // IP Header (20 bytes)
        packet[0] = 0x45.toByte() // Version 4, IHL 5
        packet[1] = 0x00.toByte() // TOS
        packet[2] = ((totalLen shr 8) and 0xFF).toByte()
        packet[3] = (totalLen and 0xFF).toByte()
        val id = (System.currentTimeMillis() and 0xFFFF).toInt()
        packet[4] = ((id shr 8) and 0xFF).toByte()
        packet[5] = (id and 0xFF).toByte()
        packet[6] = 0x40.toByte() // Don't fragment
        packet[7] = 0x00.toByte()
        packet[8] = 64.toByte() // TTL 64
        packet[9] = 6.toByte() // Protocol TCP

        val srcParts = srcIp.split(".")
        val dstParts = dstIp.split(".")
        if (srcParts.size != 4 || dstParts.size != 4) return
        for (i in 0..3) {
            packet[12 + i] = srcParts[i].toInt().toByte()
            packet[16 + i] = dstParts[i].toInt().toByte()
        }

        // IP Checksum
        val ipChecksum = computeChecksum(packet, 0, 20)
        packet[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        packet[11] = (ipChecksum and 0xFF).toByte()

        // TCP Header (at offset 20)
        val tcpOffset = 20
        packet[tcpOffset] = ((srcPort shr 8) and 0xFF).toByte()
        packet[tcpOffset + 1] = (srcPort and 0xFF).toByte()
        packet[tcpOffset + 2] = ((dstPort shr 8) and 0xFF).toByte()
        packet[tcpOffset + 3] = (dstPort and 0xFF).toByte()

        // Sequence Number (4 bytes)
        packet[tcpOffset + 4] = ((seq shr 24) and 0xFF).toByte()
        packet[tcpOffset + 5] = ((seq shr 16) and 0xFF).toByte()
        packet[tcpOffset + 6] = ((seq shr 8) and 0xFF).toByte()
        packet[tcpOffset + 7] = (seq and 0xFF).toByte()

        // Acknowledgment Number (4 bytes)
        packet[tcpOffset + 8] = ((ack shr 24) and 0xFF).toByte()
        packet[tcpOffset + 9] = ((ack shr 16) and 0xFF).toByte()
        packet[tcpOffset + 10] = ((ack shr 8) and 0xFF).toByte()
        packet[tcpOffset + 11] = (ack and 0xFF).toByte()

        // Data offset: (tcpHeaderLen / 4) << 4
        packet[tcpOffset + 12] = ((tcpHeaderLen / 4) shl 4).toByte()
        packet[tcpOffset + 13] = (flags and 0xFF).toByte()

        // Window size (65535)
        packet[tcpOffset + 14] = 0xFF.toByte()
        packet[tcpOffset + 15] = 0xFF.toByte()

        // If SYN, append MSS Option (1360) + Window Scale (7) + SACK Permitted + NOPs (12 bytes)
        if (isSyn) {
            // MSS: Kind 2, Len 4, Val 1360 (0x0550)
            packet[tcpOffset + 20] = 0x02.toByte()
            packet[tcpOffset + 21] = 0x04.toByte()
            packet[tcpOffset + 22] = 0x05.toByte()
            packet[tcpOffset + 23] = 0x50.toByte()
            // NOP
            packet[tcpOffset + 24] = 0x01.toByte()
            // Window Scale: Kind 3, Len 3, Shift 7
            packet[tcpOffset + 25] = 0x03.toByte()
            packet[tcpOffset + 26] = 0x03.toByte()
            packet[tcpOffset + 27] = 0x07.toByte()
            // SACK Permitted: Kind 4, Len 2
            packet[tcpOffset + 28] = 0x04.toByte()
            packet[tcpOffset + 29] = 0x02.toByte()
            // NOP NOP padding
            packet[tcpOffset + 30] = 0x01.toByte()
            packet[tcpOffset + 31] = 0x01.toByte()
        }

        // Append payload if any
        if (payload != null && payloadLen > 0) {
            System.arraycopy(payload, 0, packet, tcpOffset + tcpHeaderLen, payloadLen)
        }

        // Compute TCP Checksum with pseudo-header
        val tcpSegmentLen = tcpHeaderLen + payloadLen
        val pseudoHeader = ByteArray(12)
        for (i in 0..3) {
            pseudoHeader[i] = srcParts[i].toInt().toByte()
            pseudoHeader[4 + i] = dstParts[i].toInt().toByte()
        }
        pseudoHeader[8] = 0.toByte()
        pseudoHeader[9] = 6.toByte() // TCP
        pseudoHeader[10] = ((tcpSegmentLen shr 8) and 0xFF).toByte()
        pseudoHeader[11] = (tcpSegmentLen and 0xFF).toByte()

        val tcpBuf = ByteArray(12 + tcpSegmentLen)
        System.arraycopy(pseudoHeader, 0, tcpBuf, 0, 12)
        System.arraycopy(packet, tcpOffset, tcpBuf, 12, tcpSegmentLen)

        val tcpChecksum = computeChecksum(tcpBuf, 0, tcpBuf.size)
        packet[tcpOffset + 16] = ((tcpChecksum shr 8) and 0xFF).toByte()
        packet[tcpOffset + 17] = (tcpChecksum and 0xFF).toByte()

        // Thread-safe write to TUN interface
        synchronized(tunWriteLock) {
            try {
                tunOutputStream?.write(packet)
                tunOutputStream?.flush()
            } catch (e: Exception) {
                logDiag("[TUN-WRITE-ERR] $srcIp:$srcPort -> $dstIp:$dstPort: ${e.message}")
            }
        }
    }

    private fun sendUdpPacket(
        srcIp: String,
        srcPort: Int,
        dstIp: String,
        dstPort: Int,
        payload: ByteArray
    ) {
        val totalLen = 20 + 8 + payload.size
        val packet = ByteArray(totalLen)

        // IP Header (20 bytes)
        packet[0] = 0x45.toByte()
        packet[1] = 0x00.toByte()
        packet[2] = ((totalLen shr 8) and 0xFF).toByte()
        packet[3] = (totalLen and 0xFF).toByte()
        val id = (System.currentTimeMillis() and 0xFFFF).toInt()
        packet[4] = ((id shr 8) and 0xFF).toByte()
        packet[5] = (id and 0xFF).toByte()
        packet[6] = 0x00.toByte()
        packet[7] = 0x00.toByte()
        packet[8] = 64.toByte()
        packet[9] = 17.toByte() // Protocol UDP

        val srcParts = srcIp.split(".")
        val dstParts = dstIp.split(".")
        if (srcParts.size != 4 || dstParts.size != 4) return
        for (i in 0..3) {
            packet[12 + i] = srcParts[i].toInt().toByte()
            packet[16 + i] = dstParts[i].toInt().toByte()
        }

        // IP Checksum
        val ipChecksum = computeChecksum(packet, 0, 20)
        packet[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        packet[11] = (ipChecksum and 0xFF).toByte()

        // UDP Header (8 bytes at offset 20)
        val udpOffset = 20
        packet[udpOffset] = ((srcPort shr 8) and 0xFF).toByte()
        packet[udpOffset + 1] = (srcPort and 0xFF).toByte()
        packet[udpOffset + 2] = ((dstPort shr 8) and 0xFF).toByte()
        packet[udpOffset + 3] = (dstPort and 0xFF).toByte()
        val udpLen = 8 + payload.size
        packet[udpOffset + 4] = ((udpLen shr 8) and 0xFF).toByte()
        packet[udpOffset + 5] = (udpLen and 0xFF).toByte()
        packet[udpOffset + 6] = 0.toByte()
        packet[udpOffset + 7] = 0.toByte()

        System.arraycopy(payload, 0, packet, udpOffset + 8, payload.size)

        // UDP Checksum with pseudo-header
        val pseudoHeader = ByteArray(12)
        for (i in 0..3) {
            pseudoHeader[i] = srcParts[i].toInt().toByte()
            pseudoHeader[4 + i] = dstParts[i].toInt().toByte()
        }
        pseudoHeader[8] = 0.toByte()
        pseudoHeader[9] = 17.toByte() // UDP
        pseudoHeader[10] = ((udpLen shr 8) and 0xFF).toByte()
        pseudoHeader[11] = (udpLen and 0xFF).toByte()

        val udpBuf = ByteArray(12 + udpLen)
        System.arraycopy(pseudoHeader, 0, udpBuf, 0, 12)
        System.arraycopy(packet, udpOffset, udpBuf, 12, udpLen)

        var udpChecksum = computeChecksum(udpBuf, 0, udpBuf.size)
        if (udpChecksum == 0) udpChecksum = 0xFFFF
        packet[udpOffset + 6] = ((udpChecksum shr 8) and 0xFF).toByte()
        packet[udpOffset + 7] = (udpChecksum and 0xFF).toByte()

        synchronized(tunWriteLock) {
            try {
                tunOutputStream?.write(packet)
                tunOutputStream?.flush()
            } catch (e: Exception) {
                logDiag("[TUN-UDP-ERR] Write failed: ${e.message}")
            }
        }
    }

    private fun sendIcmpPortUnreachable(origPacket: ByteArray, origLength: Int) {
        if (origLength < 28) return
        val origHeaderLen = (origPacket[0].toInt() and 0x0F) * 4
        if (origLength < origHeaderLen + 8) return

        val icmpPayloadLen = origHeaderLen + 8 // original IP header + 8 bytes of UDP
        val icmpTotalLen = 8 + icmpPayloadLen
        val totalLen = 20 + icmpTotalLen
        val packet = ByteArray(totalLen)

        // IP Header (20 bytes)
        packet[0] = 0x45.toByte() // IPv4, IHL 5
        packet[1] = 0x00.toByte() // TOS
        packet[2] = ((totalLen shr 8) and 0xFF).toByte()
        packet[3] = (totalLen and 0xFF).toByte()
        val id = (System.currentTimeMillis() and 0xFFFF).toInt()
        packet[4] = ((id shr 8) and 0xFF).toByte()
        packet[5] = (id and 0xFF).toByte()
        packet[6] = 0x00.toByte()
        packet[7] = 0x00.toByte()
        packet[8] = 64.toByte() // TTL
        packet[9] = 1.toByte()  // Protocol ICMP

        // Source IP = original packet's destination IP (host unreachable)
        System.arraycopy(origPacket, 16, packet, 12, 4)
        // Destination IP = original packet's source IP (the client app)
        System.arraycopy(origPacket, 12, packet, 16, 4)

        // IP Checksum
        val ipChecksum = computeChecksum(packet, 0, 20)
        packet[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        packet[11] = (ipChecksum and 0xFF).toByte()

        // ICMP Header (offset 20)
        val icmpOffset = 20
        packet[icmpOffset] = 3.toByte() // Type 3: Destination Unreachable
        packet[icmpOffset + 1] = 3.toByte() // Code 3: Port Unreachable
        packet[icmpOffset + 2] = 0.toByte() // Checksum placeholder
        packet[icmpOffset + 3] = 0.toByte()
        packet[icmpOffset + 4] = 0.toByte() // Unused
        packet[icmpOffset + 5] = 0.toByte()
        packet[icmpOffset + 6] = 0.toByte()
        packet[icmpOffset + 7] = 0.toByte()

        // Copy original IP header + first 8 bytes of original transport header
        System.arraycopy(origPacket, 0, packet, icmpOffset + 8, icmpPayloadLen)

        // ICMP Checksum
        val icmpChecksum = computeChecksum(packet, icmpOffset, icmpTotalLen)
        packet[icmpOffset + 2] = ((icmpChecksum shr 8) and 0xFF).toByte()
        packet[icmpOffset + 3] = (icmpChecksum and 0xFF).toByte()

        synchronized(tunWriteLock) {
            try {
                tunOutputStream?.write(packet)
                tunOutputStream?.flush()
            } catch (e: Exception) {
                logDiag("[ICMP-WRITE-ERR] Failed writing ICMP Port Unreachable: ${e.message}")
            }
        }
    }

    private fun computeChecksum(buf: ByteArray, offset: Int, length: Int): Int {
        var sum = 0
        var i = offset
        val end = offset + length
        while (i < end - 1) {
            val word = ((buf[i].toInt() and 0xFF) shl 8) or (buf[i + 1].toInt() and 0xFF)
            sum += word
            i += 2
        }
        if (i < end) {
            sum += ((buf[i].toInt() and 0xFF) shl 8)
        }
        while ((sum shr 16) > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        return (sum.inv()) and 0xFFFF
    }

    private fun readExact(inStream: InputStream, target: ByteArray, offset: Int, length: Int) {
        var total = 0
        while (total < length) {
            val r = inStream.read(target, offset + total, length - total)
            if (r == -1) throw java.io.EOFException("Unexpected EOF from proxy")
            total += r
        }
    }

    private fun handshakeSocks5(out: OutputStream, `in`: InputStream, dstIp: String, dstPort: Int): Boolean {
        try {
            logDiag("[SOCKS5] Sending greeting to $targetHost:$targetPort...")
            out.write(byteArrayOf(0x05, 0x01, 0x00))
            out.flush()

            val resp = ByteArray(2)
            readExact(`in`, resp, 0, 2)
            if (resp[0] != 0x05.toByte() || resp[1] != 0x00.toByte()) {
                logDiag("[SOCKS5-ERR] Greeting rejected: ver=${resp[0]}, auth=${resp[1]}")
                return false
            }

            logDiag("[SOCKS5] Greeting accepted. Sending CONNECT to $dstIp:$dstPort...")

            val ipParts = dstIp.split(".")
            if (ipParts.size != 4) {
                logDiag("[SOCKS5-ERR] Invalid destination IPv4: $dstIp")
                return false
            }

            val req = ByteArray(10)
            req[0] = 0x05
            req[1] = 0x01
            req[2] = 0x00
            req[3] = 0x01
            req[4] = ipParts[0].toInt().toByte()
            req[5] = ipParts[1].toInt().toByte()
            req[6] = ipParts[2].toInt().toByte()
            req[7] = ipParts[3].toInt().toByte()
            req[8] = ((dstPort shr 8) and 0xFF).toByte()
            req[9] = (dstPort and 0xFF).toByte()

            out.write(req)
            out.flush()

            val header = ByteArray(4)
            readExact(`in`, header, 0, 4)
            val ver = header[0].toInt() and 0xFF
            val rep = header[1].toInt() and 0xFF
            val atyp = header[3].toInt() and 0xFF

            if (rep != 0x00) {
                logDiag("[SOCKS5-ERR] Proxy CONNECT to $dstIp:$dstPort FAILED with reply code: $rep")
                return false
            }

            // Drain bound address and port completely based on ATYP
            when (atyp) {
                0x01 -> { // IPv4: 4 bytes IP + 2 bytes port
                    val addrPort = ByteArray(6)
                    readExact(`in`, addrPort, 0, 6)
                }
                0x03 -> { // Domain: 1 byte len + N bytes domain + 2 bytes port
                    val lenBuf = ByteArray(1)
                    readExact(`in`, lenBuf, 0, 1)
                    val domainLen = lenBuf[0].toInt() and 0xFF
                    val domainPort = ByteArray(domainLen + 2)
                    readExact(`in`, domainPort, 0, domainPort.size)
                }
                0x04 -> { // IPv6: 16 bytes IP + 2 bytes port
                    val addrPort = ByteArray(18)
                    readExact(`in`, addrPort, 0, 18)
                }
                else -> {
                    logDiag("[SOCKS5-ERR] Unknown ATYP in reply: $atyp")
                    return false
                }
            }

            logDiag("[SOCKS5] Proxy CONNECT to $dstIp:$dstPort SUCCEEDED (0x00, atyp=$atyp)")
            return true
        } catch (e: Exception) {
            logDiag("[SOCKS5-ERR] Handshake exception: ${e.message}")
            return false
        }
    }

    private fun handshakeHttpConnect(out: OutputStream, `in`: InputStream, dstIp: String, dstPort: Int): Boolean {
        logDiag("[HTTP] Sending CONNECT $dstIp:$dstPort HTTP/1.1 to $targetHost:$targetPort...")
        val connectStr = "CONNECT $dstIp:$dstPort HTTP/1.1\r\nHost: $dstIp:$dstPort\r\nProxy-Connection: Keep-Alive\r\nUser-Agent: FDServer/1.0\r\n\r\n"
        out.write(connectStr.toByteArray(Charsets.US_ASCII))
        out.flush()

        val responseHeader = StringBuilder()
        val byteBuf = ByteArray(1)
        while (`in`.read(byteBuf) != -1) {
            val c = byteBuf[0].toInt().toChar()
            responseHeader.append(c)
            if (responseHeader.endsWith("\r\n\r\n")) break
            if (responseHeader.length > 2048) break
        }

        val statusLine = responseHeader.lines().firstOrNull() ?: ""
        logDiag("[HTTP] Proxy response: $statusLine")
        val ok = statusLine.contains("200")
        if (ok) {
            logDiag("[HTTP] Proxy tunnel to $dstIp:$dstPort ESTABLISHED (HTTP 200 OK)")
        } else {
            logDiag("[HTTP-ERR] Proxy tunnel to $dstIp:$dstPort REJECTED: $statusLine")
        }
        return ok
    }

    private fun stopVpn() {
        if (!isRunning && !isStopping.get()) return

        logDiag("=== VPN STOP REQUESTED ===")
        logDiag("Closing TUN interface and ${activeSessions.size} active sessions.")

        isStopping.set(true)
        isRunning = false

        // Close all active sockets
        activeSessions.forEach { (_, session) ->
            try {
                session.proxySocket?.close()
            } catch (_: Exception) {}
        }
        activeSessions.clear()
        dnsCache.clear()

        try {
            vpnInterface?.close()
        } catch (_: Exception) {}
        vpnInterface = null
        tunOutputStream = null

        workerExecutor?.shutdownNow()
        workerExecutor = null

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {}

        onStateChangeListener?.invoke(false, lastError)
        logDiag("VPN Service stopped completely.")
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "FDServer Proxy Diverter"
            val desc = "Active VPN tunnel forwarding device traffic to proxy"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = desc
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        createNotificationChannel()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val appIcon = try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            if (info.icon != 0) info.icon else android.R.drawable.ic_dialog_info
        } catch (_: Throwable) {
            android.R.drawable.ic_dialog_info
        }

        return builder
            .setContentTitle("FDServer Proxy Diverter Active")
            .setContentText("Diverting all device traffic to $targetHost:$targetPort ($targetProtocol)")
            .setSmallIcon(appIcon)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }
}
