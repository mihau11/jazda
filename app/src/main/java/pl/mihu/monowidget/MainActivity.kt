package pl.mihu.monowidget

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

/**
 * Ekran pomocniczy: pokazuje aktualny stan, mowi czy uprawnienie jest nadane i podaje
 * komende ADB do skopiowania. Sam widget dziala bez otwierania tej aktywnosci.
 */
class MainActivity : AppCompatActivity() {

    private lateinit var stateView: TextView
    private lateinit var permissionView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        stateView = findViewById(R.id.state)
        permissionView = findViewById(R.id.permission_status)

        findViewById<TextView>(R.id.adb_command).text = MonoController.ADB_COMMAND

        findViewById<Button>(R.id.copy_command).setOnClickListener {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(
                ClipData.newPlainText("adb", MonoController.ADB_COMMAND)
            )
            Toast.makeText(this, R.string.toast_copied, Toast.LENGTH_SHORT).show()
        }

        findViewById<Button>(R.id.open_settings).setOnClickListener {
            MonoController.openAccessibilitySettings(this)
        }

        findViewById<Button>(R.id.toggle).setOnClickListener {
            when (MonoController.toggle(this)) {
                is MonoController.ToggleResult.Toggled -> Unit
                MonoController.ToggleResult.NoPermission ->
                    Toast.makeText(this, R.string.toast_no_permission, Toast.LENGTH_LONG).show()
            }
            refresh()
        }
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh() {
        val mono = MonoController.isMono(this)
        stateView.setText(if (mono) R.string.state_mono else R.string.state_stereo)
        permissionView.setText(
            if (MonoController.canWrite(this)) R.string.permission_granted
            else R.string.permission_missing
        )
        // Ustawienie moglo zmienic sie poza aplikacja - niech widget nie klamie.
        MonoWidgetProvider.refreshAll(this)
    }
}
