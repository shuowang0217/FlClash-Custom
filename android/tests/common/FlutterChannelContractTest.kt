package com.follow.clash.common

import org.junit.Assert.assertEquals
import org.junit.Test

/** Native class namespace is NOT the Flutter MethodChannel namespace. */
class FlutterChannelContractTest {
    @Test
    fun `SHUO Flutter channel namespace stays aligned with Dart`() {
        assertEquals("com.shuowang.flclash.custom", Components.FLUTTER_CHANNEL_NAMESPACE)
        assertEquals("com.follow.clash", Components.PACKAGE_NAME)
    }
}
