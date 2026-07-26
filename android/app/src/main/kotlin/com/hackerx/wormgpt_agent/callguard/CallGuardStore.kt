package com.hackerx.wormgpt_agent.callguard

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object CallGuardStore {
    private val cache = mutableMapOf<String, Any>()
    private fun invalidate() { cache.clear() }

    const val PREFS = "wormgpt_callguard"

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(ctx: Context): Boolean = prefs(ctx).getBoolean("enabled", false)
    fun blockPrivate(ctx: Context): Boolean = prefs(ctx).getBoolean("block_private", false)

    fun setEnabled(ctx: Context, v: Boolean) {
        invalidate()
        prefs(ctx).edit().putBoolean("enabled", v).apply()
    }

    fun setBlockPrivate(ctx: Context, v: Boolean) {
        invalidate()
        prefs(ctx).edit().putBoolean("block_private", v).apply()
    }

    fun getBool(ctx: Context, key: String, def: Boolean = false): Boolean = prefs(ctx).getBoolean(key, def)

    fun setBool(ctx: Context, key: String, v: Boolean) {
        invalidate()
        prefs(ctx).edit().putBoolean(key, v).apply()
    }

    private fun arr(ctx: Context, key: String): List<String> {
        if (cache.containsKey(key)) return cache[key] as List<String>
        val raw = prefs(ctx).getString(key, "[]") ?: "[]"
        val list = try {
            val a = JSONArray(raw)
            (0 until a.length()).map { a.getString(it) }
        } catch (_: Exception) { emptyList() }
        cache[key] = list
        return list
    }

    fun setArray(ctx: Context, key: String, items: List<String>) {
        invalidate()
        val a = JSONArray()
        items.forEach { a.put(it) }
        prefs(ctx).edit().putString(key, a.toString()).apply()
    }

    fun digits(raw: String?): String = (raw ?: "").replace(Regex("[^0-9]"), "")

    fun shouldBlock(ctx: Context, raw: String?, isPrivate: Boolean): Boolean {
        if (!isEnabled(ctx)) return false
        if (isPrivate) return blockPrivate(ctx)

        val d = digits(raw)
        if (d.isEmpty()) return blockPrivate(ctx)

        if (getBool(ctx, "allowlist_enabled")) {
            val allowed = arr(ctx, "allow_exact").any { digits(it) == d }
            return !allowed
        }

        if (arr(ctx, "block_exact").any { digits(it) == d }) return true
        if (arr(ctx, "block_prefix").any { p -> d.startsWith(digits(p)) }) return true
        for (pat in arr(ctx, "block_regex")) {
            try { if (Regex(pat).containsMatchIn(d)) return true } catch (_: Exception) {}
        }
        return false
    }

    fun shouldBlockWhatsApp(ctx: Context, contactName: String?, kind: String): Boolean {
        if (!getBool(ctx, "wa_enabled")) return false
        if (kind == "call" && !getBool(ctx, "wa_block_calls", true)) return false
        if (kind == "audio" && !getBool(ctx, "wa_block_audio")) return false

        val name = (contactName ?: "").trim()
        val nameLc = name.lowercase()

        val blockNames = arr(ctx, "wa_block_names")
        if (blockNames.any { it.trim().isNotEmpty() && nameLc.contains(it.trim().lowercase()) }) return true

        if (getBool(ctx, "wa_block_unknown")) {
            val allowNames = arr(ctx, "wa_allow_names")
            val allowed = name.isNotEmpty() &&
                allowNames.any { it.trim().isNotEmpty() && nameLc.contains(it.trim().lowercase()) }
            return !allowed
        }
        return false
    }

    fun appendLog(ctx: Context, number: String?, isPrivate: Boolean, blocked: Boolean, label: String?) {
        // ... log append logic unchanged
    }
}