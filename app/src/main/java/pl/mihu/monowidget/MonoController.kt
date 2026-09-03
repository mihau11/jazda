package pl.mihu.monowidget

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings

/**
 * Cala wiedza o systemowym przelaczniku "Dzwiek mono".
 *
 * Ustawienie zyje w Settings.Secure pod ukrytym kluczem "master_mono" (0 = stereo, 1 = mono).
 * Odczyt jest publiczny, zapis wymaga WRITE_SECURE_SETTINGS - uprawnienia, ktorego zwykla
 * aplikacja nie dostanie z dialogu; nadaje sie je jednorazowo przez ADB (patrz [ADB_COMMAND]).
 */
object MonoController {

    private const val KEY_MASTER_MONO = "master_mono"

    const val ADB_COMMAND =
        "adb shell pm grant pl.mihu.monowidget android.permission.WRITE_SECURE_SETTINGS"

    sealed interface ToggleResult {
        data class Toggled(val mono: Boolean) : ToggleResult
        data object NoPermission : ToggleResult
    }

    fun isMono(context: Context): Boolean =
        Settings.Secure.getInt(context.contentResolver, KEY_MASTER_MONO, 0) == 1

    fun canWrite(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) ==
            PackageManager.PERMISSION_GRANTED

    fun toggle(context: Context): ToggleResult {
        val target = !isMono(context)
        return try {
            val ok = Settings.Secure.putInt(
                context.contentResolver,
                KEY_MASTER_MONO,
                if (target) 1 else 0,
            )
            if (ok) ToggleResult.Toggled(target) else ToggleResult.NoPermission
        } catch (_: SecurityException) {
            ToggleResult.NoPermission
        }
    }

    /**
     * Nie ma publicznej akcji prowadzacej wprost do przelacznika mono - ladujemy na ekranie
     * Dostepnosci, gdzie siedzi on w sekcji audio.
     */
    fun openAccessibilitySettings(context: Context) {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
