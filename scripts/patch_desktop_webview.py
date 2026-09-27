import os
import sys

def patch():
    path = os.path.expandvars(r'%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\desktop_webview_window-0.3.0\windows\web_view.cc')
    if not os.path.exists(path):
        print(f"File not found: {path}")
        return

    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    target_idx = None
    for i, line in enumerate(lines):
        if 'if (triggerOnUrlRequestedEvent) {' in line and i > 150 and i < 200:
            target_idx = i
            break

    if target_idx is None:
        print("Target block not found, possibly already patched.")
        return

    # Check if already patched
    if any('bool is_http' in l for l in lines[target_idx:target_idx+50]):
        print("Already patched with is_http check.")
        return

    new_block = '''            if (triggerOnUrlRequestedEvent) {
              wil::unique_cotaskmem_string uri;
              HRESULT hr = args->get_Uri(&uri);
              if (FAILED(hr) || !uri) {
                args->put_Cancel(true);
                return S_OK;
              }

              std::wstring uri_string(uri.get());
              bool is_http = uri_string.rfind(L"http://", 0) == 0 || uri_string.rfind(L"https://", 0) == 0;

              if (!is_http) {
                args->put_Cancel(true);
                method_channel_->InvokeMethod(
                    "onUrlRequested",
                    std::make_unique<flutter::EncodableValue>(
                        flutter::EncodableMap{
                            {flutter::EncodableValue("id"),
                             flutter::EncodableValue(web_view_id_)},
                            {flutter::EncodableValue("url"),
                             flutter::EncodableValue(
                                 wide_to_utf8(uri_string))},
                        }));
              } else {
                args->put_Cancel(false);
                method_channel_->InvokeMethod(
                    "onUrlRequested",
                    std::make_unique<flutter::EncodableValue>(
                        flutter::EncodableMap{
                            {flutter::EncodableValue("id"),
                             flutter::EncodableValue(web_view_id_)},
                            {flutter::EncodableValue("url"),
                             flutter::EncodableValue(
                                 wide_to_utf8(uri_string))},
                        }));
              }
            } else {
              args->put_Cancel(false);
              triggerOnUrlRequestedEvent = true;
            }
'''
    # Find closing of this block
    end_idx = None
    for j in range(target_idx, target_idx + 60):
        if 'args->put_Cancel(true);' in lines[j]:
            end_idx = j + 5
            break

    if end_idx is not None:
        lines[target_idx:end_idx] = [new_block]
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print("Successfully applied web_view.cc patch!")
    else:
        print("Could not find end of target block.")

if __name__ == '__main__':
    patch()
