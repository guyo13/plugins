package io.flutter.plugins.urllauncher;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import static io.flutter.plugins.urllauncher.WebViewActivity.ACTION_INTERCEPT_URL;
import static io.flutter.plugins.urllauncher.WebViewActivity.INTERCEPTED_URL;

/**
 * Plugin implementation that uses the new {@code io.flutter.embedding} package.
 *
 * <p>Instantiate this in an add to app scenario to gracefully handle activity and context changes.
 */
public final class UrlLauncherPlugin implements FlutterPlugin, ActivityAware {
  private static final String TAG = "UrlLauncherPlugin";
  @Nullable private MethodCallHandlerImpl methodCallHandler;
  @Nullable private UrlLauncher urlLauncher;
  @Nullable private FlutterPluginBinding pluginBinding;

  public static String INTERCEPT_URL_METHOD_NAME = "interceptUrl";

  private final BroadcastReceiver broadcastReceiver =
          new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
              String action = intent.getAction();
              String url = intent.getStringExtra(INTERCEPTED_URL);
              Log.d(TAG, "Firing onReceive for url: " + url);
              if (ACTION_INTERCEPT_URL.equals(action)) {
                if (methodCallHandler != null && methodCallHandler.channel != null) {
                  methodCallHandler.channel.invokeMethod(INTERCEPT_URL_METHOD_NAME, url);
                }
              }
            }
          };
  private IntentFilter interceptUrlIntentFilter = new IntentFilter(ACTION_INTERCEPT_URL);

  /**
   * Registers a plugin implementation that uses the stable {@code io.flutter.plugin.common}
   * package.
   *
   * <p>Calling this automatically initializes the plugin. However plugins initialized this way
   * won't react to changes in activity or context, unlike {@link UrlLauncherPlugin}.
   */
  public static void registerWith(Registrar registrar) {
    Log.d(TAG, "registerWith");
    MethodCallHandlerImpl handler =
        new MethodCallHandlerImpl(new UrlLauncher(registrar.context(), registrar.activity()));
    handler.startListening(registrar.messenger());
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    Log.d(TAG, "onAttachedToEngine");
    pluginBinding = binding;
    pluginBinding.getApplicationContext().registerReceiver(broadcastReceiver, interceptUrlIntentFilter);

    urlLauncher = new UrlLauncher(binding.getApplicationContext(), /*activity=*/ null);
    methodCallHandler = new MethodCallHandlerImpl(urlLauncher);
    methodCallHandler.startListening(binding.getBinaryMessenger());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    Log.d(TAG, "onDetachedFromEngine");
    if (methodCallHandler == null) {
      Log.wtf(TAG, "Already detached from the engine.");
      return;
    }
    pluginBinding = null;
    binding.getApplicationContext().unregisterReceiver(broadcastReceiver);
    methodCallHandler.stopListening();
    methodCallHandler = null;
    urlLauncher = null;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    Log.d(TAG, "onAttachedToActivity");
    if (methodCallHandler == null) {
      Log.wtf(TAG, "urlLauncher was never set.");
      return;
    }

    urlLauncher.setActivity(binding.getActivity());
  }

  @Override
  public void onDetachedFromActivity() {
    Log.d(TAG, "onDetachedFromActivity");
    if (methodCallHandler == null) {
      Log.wtf(TAG, "urlLauncher was never set.");
      return;
    }

    urlLauncher.setActivity(null);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    Log.d(TAG, "onDetachedFromActivityForConfigChanges");
    onDetachedFromActivity();

  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    Log.d(TAG, "onReattachedToActivityForConfigChanges");
    onAttachedToActivity(binding);
  }
}
