package com.example.duan_kmessapp

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Khởi tạo Facebook SDK
        FacebookSdk.sdkInitialize(applicationContext)
        // Kích hoạt App Events Logger
        AppEventsLogger.activateApp(application)
    }
}
