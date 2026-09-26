package com.hasif.fdserver.fdserver.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

class ProxyVpnService : VpnService() {

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
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private val isStopping = AtomicBoolean(false)
    private var workerExecutor: ExecutorService? = null

    // Track active connection tunnels (key: "srcIp:srcPort->dstIp:dstPort")
    private val activeTunnels = ConcurrentHashMap<String, Socket>()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
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

            startForeground(NOTIFICATION_ID, createNotification())
            startVpn(targetHost, targetPort, targetProtocol, bypassLan)
        }

        return START_STICKY
    }

    private fun startVpn(host: String, port: Int, protocol: String, bypassLan: Boolean) {
        if (isRunning) return

        isStopping.set(false)
        totalBytesIn.set(0)
        totalBytesOut.set(0)
        lastError = null

        workerExecutor = Executors.newCachedThreadPool()

        workerExecutor?.execute {
            try {
                val builder = Builder()
                    .setSession("FDServer Proxy Diverter")
                    .addAddress("10.0.0.2", 24)
                    .addDnsServer("8.8.8.8")
                    .addDnsServer("1.1.1.1")
                    .setMtu(1500)

                // Route all IPv4 traffic into the virtual TUN interface
                builder.addRoute("0.0.0.0", 0)

                // Exclude FDServer itself so its own connection to the proxy doesn't loop back!
                try {
                    builder.addDisallowedApplication(packageName)
                } catch (e: Exception) {
                    Log.w(TAG, "addDisallowedApplication failed: ${e.message}")
                }

                vpnInterface = builder.establish()
                if (vpnInterface == null) {
                    lastError = "Failed to establish VPN TUN interface."
                    stopVpn()
                    return@execute
                }

                isRunning = true
                onStateChangeListener?.invoke(true, null)
                Log.i(TAG, "VPN TUN interface established. Diverting to $host:$port via $protocol")

                // Start packet processing loop
                runTunLoop(vpnInterface!!)

            } catch (e: Exception) {
                Log.e(TAG, "Error starting VPN: ${e.message}", e)
                lastError = e.message
                stopVpn()
            }
        }
    }

    private fun runTunLoop(descriptor: ParcelFileDescriptor) {
        val inputStream = FileInputStream(descriptor.fileDescriptor)
        val outputStream = FileOutputStream(descriptor.fileDescriptor)
        val packet = ByteArray(32768)

        while (!isStopping.get()) {
            try {
                val length = inputStream.read(packet)
                if (length <= 0) {
                    Thread.sleep(10)
                    continue
                }

                totalBytesOut.addAndGet(length.toLong())

                // Process IP packet header
                processIpPacket(packet, length, outputStream)

            } catch (e: Exception) {
                if (!isStopping.get()) {
                    Log.e(TAG, "TUN loop exception: ${e.message}")
                }
                break
            }
        }
    }

    private fun processIpPacket(packet: ByteArray, length: Int, tunOutput: FileOutputStream) {
        if (length < 20) return
        val version = (packet[0].toInt() shr 4) and 0x0F
        if (version != 4) return // Only IPv4 for proxy redirect

        val protocol = packet[9].toInt() and 0xFF
        val headerLen = (packet[0].toInt() and 0x0F) * 4

        val srcIp = "${packet[12].toInt() and 0xFF}.${packet[13].toInt() and 0xFF}.${packet[14].toInt() and 0xFF}.${packet[15].toInt() and 0xFF}"
        val dstIp = "${packet[16].toInt() and 0xFF}.${packet[17].toInt() and 0xFF}.${packet[18].toInt() and 0xFF}.${packet[19].toInt() and 0xFF}"

        // Skip internal loopback
        if (dstIp.startsWith("10.0.0.") || dstIp == "127.0.0.1") return

        // For TCP (Protocol 6)
        if (protocol == 6 && length >= headerLen + 20) {
            val srcPort = ((packet[headerLen].toInt() and 0xFF) shl 8) or (packet[headerLen + 1].toInt() and 0xFF)
            val dstPort = ((packet[headerLen + 2].toInt() and 0xFF) shl 8) or (packet[headerLen + 3].toInt() and 0xFF)
            val flags = packet[headerLen + 13].toInt() and 0xFF
            val isSyn = (flags and 0x02) != 0

            val connKey = "$srcIp:$srcPort->$dstIp:$dstPort"

            // Dispatch to worker thread for proxy tunneling
            if (isSyn && !activeTunnels.containsKey(connKey)) {
                workerExecutor?.execute {
                    handleTcpConnection(connKey, dstIp, dstPort)
                }
            }
        }
    }

    private fun handleTcpConnection(connKey: String, dstIp: String, dstPort: Int) {
        var proxySocket: Socket? = null
        try {
            proxySocket = Socket()
            // CRITICAL: Protect socket so its packets bypass the VPN TUN and go straight to Wi-Fi/Hotspot!
            protect(proxySocket)

            proxySocket.connect(InetSocketAddress(targetHost, targetPort), 5000)
            activeTunnels[connKey] = proxySocket

            val inStream = proxySocket.getInputStream()
            val outStream = proxySocket.getOutputStream()

            // Perform proxy handshake
            val connected = if (targetProtocol.equals("HTTP", ignoreCase = true)) {
                handshakeHttpConnect(outStream, inStream, dstIp, dstPort)
            } else {
                handshakeSocks5(outStream, inStream, dstIp, dstPort)
            }

            if (!connected) {
                proxySocket.close()
                activeTunnels.remove(connKey)
                return
            }

            // Pipe incoming responses
            val buffer = ByteArray(16384)
            var readLen = 0
            while (!isStopping.get() && inStream.read(buffer).also { readLen = it } != -1) {
                totalBytesIn.addAndGet(readLen.toLong())
            }

        } catch (e: Exception) {
            // Normal connection close or timeout
        } finally {
            try {
                proxySocket?.close()
            } catch (_: Exception) {}
            activeTunnels.remove(connKey)
        }
    }

    private fun handshakeSocks5(out: OutputStream, `in`: InputStream, dstIp: String, dstPort: Int): Boolean {
        // SOCKS5 Greeting: Version 5, 1 Method, No Auth (0x00)
        out.write(byteArrayOf(0x05, 0x01, 0x00))
        out.flush()

        val resp = ByteArray(2)
        if (`in`.read(resp) != 2 || resp[0] != 0x05.toByte() || resp[1] != 0x00.toByte()) {
            return false
        }

        // SOCKS5 Connect Request: Ver 5, CMD 1 (CONNECT), RSV 0, ATYP 1 (IPv4)
        val ipParts = dstIp.split(".")
        if (ipParts.size != 4) return false

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

        val connResp = ByteArray(10)
        val readLen = `in`.read(connResp)
        return readLen >= 4 && connResp[1] == 0x00.toByte()
    }

    private fun handshakeHttpConnect(out: OutputStream, `in`: InputStream, dstIp: String, dstPort: Int): Boolean {
        val connectStr = "CONNECT $dstIp:$dstPort HTTP/1.1\r\nHost: $dstIp:$dstPort\r\nProxy-Connection: Keep-Alive\r\n\r\n"
        out.write(connectStr.toByteArray(Charsets.US_ASCII))
        out.flush()

        val responseHeader = StringBuilder()
        val byteBuf = ByteArray(1)
        while (`in`.read(byteBuf) != -1) {
            val c = byteBuf[0].toInt().toChar()
            responseHeader.append(c)
            if (responseHeader.endsWith("\r\n\r\n")) break
            if (responseHeader.length > 1024) break
        }

        return responseHeader.contains("200")
    }

    private fun stopVpn() {
        if (!isRunning && !isStopping.get()) return

        isStopping.set(true)
        isRunning = false

        // Close all active sockets
        activeTunnels.forEach { (_, sock) ->
            try {
                sock.close()
            } catch (_: Exception) {}
        }
        activeTunnels.clear()

        try {
            vpnInterface?.close()
        } catch (_: Exception) {}
        vpnInterface = null

        workerExecutor?.shutdownNow()
        workerExecutor = null

        stopForeground(STOP_FOREGROUND_REMOVE)
        onStateChangeListener?.invoke(false, lastError)
        Log.i(TAG, "VPN Service stopped.")
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

        return builder
            .setContentTitle("FDServer Proxy Diverter Active")
            .setContentText("Diverting all device traffic to $targetHost:$targetPort ($targetProtocol)")
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
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
