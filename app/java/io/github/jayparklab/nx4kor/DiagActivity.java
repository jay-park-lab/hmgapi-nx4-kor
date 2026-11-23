package io.github.jayparklab.nx4kor;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.os.Handler;

import java.io.File;

/**
 * 진단 기록을 모을지 묻는 확인 창. USB 설치기(usb/troubleShooter ask_diag)가 아무것도 바꾸기 전에
 * {@code am start -n io.github.jayparklab.nx4kor/.DiagActivity --es id <id> --ei wait <초>}로 연다.
 * 답은 앱 폴더의 diag.ans에 "<id> <답>" 한 줄로 쓴다(root인 설치기가 읽음, Report.diagLine).
 * 열리면 shown, [모으기]는 yes, [건너뛰기]·뒤로는 no, wait초 안에 고르지 않으면 timeout을 쓰고 닫는다.
 * 화면은 투명해서 확인 창만 DSP OTA 화면 위에 보인다. id가 없으면(설치기가 연 것이 아님) 아무것도 쓰지 않고 닫는다.
 * 버튼은 익명 클래스 대신 이 화면이 직접 받는다(JDK 21 + d8 8.2가 익명 클래스에서 멈춤, StatusActivity와 같음).
 */
public class DiagActivity extends Activity
        implements DialogInterface.OnClickListener, DialogInterface.OnCancelListener, Runnable {
    /** 답 파일 이름(앱 개인 폴더). 설치기(usb/troubleShooter DIAG_ANS)와 같아야 한다 */
    static final String ANS_NAME = "diag.ans";
    static final int WAIT_DEFAULT = 60;

    final Handler handler = new Handler();
    String id;
    AlertDialog dialog;
    boolean answered;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        id = getIntent().getStringExtra("id");
        if (id == null || id.trim().isEmpty()) {
            finish();
            return;
        }
        int wait = getIntent().getIntExtra("wait", WAIT_DEFAULT);
        if (wait <= 0) wait = WAIT_DEFAULT;
        write("shown");
        dialog = new AlertDialog.Builder(this)
            .setTitle(Report.DIAG_TITLE)
            .setMessage(Report.diagAsk(wait))
            .setPositiveButton(Report.DIAG_YES, this)
            .setNegativeButton(Report.DIAG_NO, this)
            .setOnCancelListener(this)
            .create();
        dialog.setCanceledOnTouchOutside(false);
        dialog.show();
        handler.postDelayed(this, wait * 1000L);
    }

    @Override
    public void onClick(DialogInterface d, int which) {
        done(which == DialogInterface.BUTTON_POSITIVE ? "yes" : "no");
    }

    /** 뒤로 버튼: 건너뛰기와 같다 */
    @Override
    public void onCancel(DialogInterface d) {
        done("no");
    }

    /** 고르지 않고 wait초가 지남 */
    @Override
    public void run() {
        done("timeout");
    }

    void done(String word) {
        if (answered) return;
        answered = true;
        handler.removeCallbacks(this);
        write(word);
        if (dialog != null && dialog.isShowing()) dialog.dismiss();
        finish();
    }

    void write(String word) {
        StatusActivity.writeText(new File(getFilesDir(), ANS_NAME), Report.diagLine(id, word));
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacks(this);
        if (dialog != null && dialog.isShowing()) dialog.dismiss();
        super.onDestroy();
    }
}
