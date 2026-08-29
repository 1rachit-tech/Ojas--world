package com.rachit.ojas

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
		super.onCreate(savedInstanceState)
	}
}
