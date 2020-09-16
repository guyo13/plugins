package io.flutter.plugins.urllauncher;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;
import android.provider.Browser;
import android.util.Log;
import android.view.KeyEvent;
import android.view.View;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;

import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugins.urllauncher.databinding.WebViewLayoutBinding;

/*  Launches WebView activity */
public class WebViewActivity extends Activity {

  /*
   * Use this to trigger a BroadcastReceiver inside WebViewActivity
   * that will request the current instance to finish.
   * */
  public static String ACTION_CLOSE = "close action";
  public static String ACTION_INTERCEPT_URL = "intercept url action";
  public static String INTERCEPTED_URL = "interceptedUrl";
  private static String TAG = "WebViewActivity";

  private String webUrlInterceptionPattern;
  private InterceptionType interceptionType = InterceptionType.InterceptionTypeStartsWith;
  private final WebResourceResponse emptyWebResourceResponse = new WebResourceResponse("text/plain", "utf-8", new InputStream() {
      @Override
      public int read() throws IOException {
          return 0;
      }
  });

  private final BroadcastReceiver broadcastReceiver =
      new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
          String action = intent.getAction();
          if (ACTION_CLOSE.equals(action)) {
            finish();
          }
        }
      };

  private final WebViewClient webViewClient =
      new WebViewClient() {

      private boolean needsInterception(String url) {
        if (!webUrlInterceptionPattern.isEmpty()) {
          switch (interceptionType) {
            case InterceptionTypeContains:
              return url.contains(webUrlInterceptionPattern);
            case InterceptionTypeStartsWith:
            default:
              return url.startsWith(webUrlInterceptionPattern);
          }
        } else { return false; }
      }

      private WebResourceResponse doInterceptUrl(String url, WebView view) {
          if (needsInterception(url)) {
            //FIXME - handle skipped frames, post to thread?
            Log.d(TAG, "Intercepted URL '" +
                    url +
                    "' with pattern '" +
                    webUrlInterceptionPattern +
                    "' and interception Type '" +
                    interceptionType +
                    "'notifying Flutter");
            final Intent intent = new Intent(ACTION_INTERCEPT_URL);
            intent.putExtra(INTERCEPTED_URL, url);
            sendBroadcast(intent);
            finish();
            return emptyWebResourceResponse;
          }
          return null;
      }

        @Nullable
        @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
        @Override
        public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
          final String url = request.getUrl().toString();
          Log.v(TAG, "Trying to invoke request: " + url);
          return doInterceptUrl(url, view);
        }

          @Nullable
          @SuppressWarnings("deprecation")
          @Override
          public WebResourceResponse shouldInterceptRequest(WebView view, String url) {
              Log.v(TAG, "Trying to invoke request: " + url + " (via deprecated API)");
              return doInterceptUrl(url, view);
          }

          /*
         * This method is deprecated in API 24. Still overridden to support
         * earlier Android versions.
         */
        @SuppressWarnings("deprecation")
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
          if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            view.loadUrl(url);
            return false;
          }
          return super.shouldOverrideUrlLoading(view, url);
        }

        @RequiresApi(Build.VERSION_CODES.N)
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            view.loadUrl(request.getUrl().toString());
          }
          return false;
        }
      };

  private WebView webview;

  private IntentFilter closeIntentFilter = new IntentFilter(ACTION_CLOSE);
  private WebViewLayoutBinding binding;

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    binding = WebViewLayoutBinding.inflate(getLayoutInflater());
//    webview = new WebView(this);
    webview = binding.webView;
    setContentView(binding.getRoot());
    // Get the Intent that started this activity and extract the string
    final Intent intent = getIntent();
    final String url = intent.getStringExtra(URL_EXTRA);
    final boolean enableJavaScript = intent.getBooleanExtra(ENABLE_JS_EXTRA, false);
    final boolean enableDomStorage = intent.getBooleanExtra(ENABLE_DOM_EXTRA, false);
    final String interceptType = intent.getStringExtra(INTERCEPT_TYPE);
    if (interceptType != null && !interceptType.isEmpty()) {
      interceptionType = InterceptionType.valueOf(interceptType);
    }
    webUrlInterceptionPattern = intent.getStringExtra(WEB_URL_PATTERN);
    webUrlInterceptionPattern = webUrlInterceptionPattern != null ? webUrlInterceptionPattern : "";
    final Bundle headersBundle = intent.getBundleExtra(Browser.EXTRA_HEADERS);

    final Map<String, String> headersMap = extractHeaders(headersBundle);
    webview.loadUrl(url, headersMap);

    webview.getSettings().setJavaScriptEnabled(enableJavaScript);
    webview.getSettings().setDomStorageEnabled(enableDomStorage);

    // Open new urls inside the webview itself.
    webview.setWebViewClient(webViewClient);

    // Register receiver that may finish this Activity.
    registerReceiver(broadcastReceiver, closeIntentFilter);
    binding.backButton.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        if (webview.canGoBack()) {
          webview.goBack();
        } else {
          finish();
        }
      }
    });
  }

  private Map<String, String> extractHeaders(Bundle headersBundle) {
    final Map<String, String> headersMap = new HashMap<>();
    for (String key : headersBundle.keySet()) {
      final String value = headersBundle.getString(key);
      headersMap.put(key, value);
    }
    return headersMap;
  }

  @Override
  protected void onDestroy() {
    Log.i(TAG, "onDestroy!");
    super.onDestroy();
    unregisterReceiver(broadcastReceiver);
  }

  @Override
  public boolean onKeyDown(int keyCode, KeyEvent event) {
    if (keyCode == KeyEvent.KEYCODE_BACK && webview.canGoBack()) {
      webview.goBack();
      return true;
    }
    return super.onKeyDown(keyCode, event);
  }

  private static String URL_EXTRA = "url";
  private static String ENABLE_JS_EXTRA = "enableJavaScript";
  private static String ENABLE_DOM_EXTRA = "enableDomStorage";
  private static String WEB_URL_PATTERN = "webUrlInterceptionPattern";
  private static String INTERCEPT_TYPE = "interceptionType";

  /* Hides the constants used to forward data to the Activity instance. */
  public static Intent createIntent(
      Context context,
      String url,
      boolean enableJavaScript,
      boolean enableDomStorage,
      boolean interceptStartsWith,
      boolean interceptContains,
      String webUrlInterceptionPattern,
      Bundle headersBundle) {

    InterceptionType interceptionType = InterceptionType.InterceptionTypeStartsWith;
    if (interceptContains && interceptStartsWith) {
      Log.w(TAG, "Both interceptContains and interceptStartsWith specified. Defaulting to interceptStartsWith");
    } else if (interceptContains) {
      interceptionType = InterceptionType.InterceptionTypeContains;
    }
    return new Intent(context, WebViewActivity.class)
        .putExtra(URL_EXTRA, url)
        .putExtra(ENABLE_JS_EXTRA, enableJavaScript)
        .putExtra(ENABLE_DOM_EXTRA, enableDomStorage)
        .putExtra(INTERCEPT_TYPE, interceptionType.name())
        .putExtra(WEB_URL_PATTERN, webUrlInterceptionPattern)
        .putExtra(Browser.EXTRA_HEADERS, headersBundle);
  }

  public enum InterceptionType { InterceptionTypeStartsWith, InterceptionTypeContains};
}
