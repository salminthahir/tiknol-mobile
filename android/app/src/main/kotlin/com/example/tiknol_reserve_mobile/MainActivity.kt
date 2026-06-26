package com.example.tiknol_reserve_mobile

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lockLandscape()
    }

    override fun onResume() {
        super.onResume()
        lockLandscape()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        lockLandscape()
    }

    private fun lockLandscape() {
        val target = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        if (requestedOrientation != target) {
            requestedOrientation = target
        }
    }
}
