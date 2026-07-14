package com.mmtech.axisvtu

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "custom_sound_channel"
            val channelName = "App Notifications"
            val channelDescription = "Notifications with custom sounds"
            
            val soundUri = Uri.parse(ContentResolver.SCHEME_ANDROID_RESOURCE + "://" + packageName + "/raw/balance_success")
            
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()
                
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH).apply {
                description = channelDescription
                setSound(soundUri, audioAttributes)
                enableVibration(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
