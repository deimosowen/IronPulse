package com.ironpulse.watch;

import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import java.io.File;
import ohos.abilityshell.AbilityShellActivity;

/**
 * Android-оболочка IronPulse (подставляется вместо сгенерированной, см. entry/hvigorfile.ts).
 *
 * Пока идёт тренировка (есть files/session.json — от «СТАРТ» до «Готово» на итоге),
 * приложение нельзя свернуть системным «назад» и свайпом вправо (swipe-to-dismiss часов).
 * Выход из тренировки — только кнопкой «Завершить» в приложении.
 * Колесико («Домой») — системная кнопка: её не перехватить, а вернуть окно из фона
 * система не даёт (Background activity start). Тренировка при этом продолжается.
 */
public class MainAbilityShellActivity extends AbilityShellActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    private boolean workoutActive() {
        return new File(getFilesDir(), "session.json").exists();
    }

    @Override
    public void onBackPressed() {
        if (workoutActive()) {
            return;
        }
        super.onBackPressed();
    }

    /** Скрытый метод Activity: вызывается, когда окно смахнули свайпом вправо. */
    public void onWindowDismissed(boolean finishTask, boolean suppressWindowTransition) {
        if (workoutActive()) {
            restoreWindow();
            return;
        }
        if (finishTask) {
            finishAndRemoveTask();
        } else {
            finish();
        }
    }

    @Override
    public void finish() {
        if (workoutActive()) {
            restoreWindow();
            return;
        }
        super.finish();
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        int code = event.getKeyCode();
        if (workoutActive() && (code == KeyEvent.KEYCODE_BACK
                || code == KeyEvent.KEYCODE_STEM_PRIMARY
                || code == KeyEvent.KEYCODE_STEM_1
                || code == KeyEvent.KEYCODE_STEM_2
                || code == KeyEvent.KEYCODE_STEM_3)) {
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    /** Жест мог сдвинуть содержимое окна — вернуть его на место. */
    private void restoreWindow() {
        final View decor = getWindow().getDecorView();
        decor.post(new Runnable() {
            @Override
            public void run() {
                reset(decor);
            }
        });
    }

    private static void reset(View v) {
        v.setTranslationX(0f);
        v.setTranslationY(0f);
        v.setAlpha(1f);
        v.setScrollX(0);
        if (v instanceof ViewGroup) {
            ViewGroup g = (ViewGroup) v;
            for (int i = 0; i < g.getChildCount(); i++) {
                reset(g.getChildAt(i));
            }
        }
    }
}
