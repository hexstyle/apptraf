class Apptraf < Formula
  desc "Lightweight per-app network traffic tracker for macOS"
  homepage "https://github.com/hexstyle/apptraf"
  url "https://github.com/hexstyle/apptraf.git",
      tag:      "v0.1.6",
      revision: "a8f1eb551c035f01035325b24dd028391e7ae5c6"
  license "MIT"
  head "https://github.com/hexstyle/apptraf.git", branch: "main"

  depends_on :macos

  def install
    system "scripts/build-app.sh", version.to_s
    prefix.install ".build/release/AppTraf.app"
    bin.install ".build/release/apptrafd"

    (bin/"apptraf").write <<~SH
      #!/bin/sh
      exec /usr/bin/open -a "#{opt_prefix}/AppTraf.app" "$@"
    SH
    (bin/"apptraf").chmod 0755

    (bin/"apptraf-install-app").write <<~SH
      #!/bin/sh
      # Copy AppTraf.app into /Applications so Spotlight indexes it.
      # Run once after `brew install`, and again after each `brew upgrade`.
      set -e

      SOURCE="#{opt_prefix}/AppTraf.app"
      TARGET="/Applications/AppTraf.app"
      LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
      BUNDLE_ID="com.hexstyle.apptraf"

      if [ ! -d "$SOURCE" ]; then
          echo "error: $SOURCE not found — is apptraf installed via brew?" >&2
          exit 1
      fi

      if [ ! -d /Applications ] || [ ! -w /Applications ]; then
          echo "error: /Applications is not writable" >&2
          exit 1
      fi

      if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
          existing_id=$(/usr/bin/defaults read "$TARGET/Contents/Info" CFBundleIdentifier 2>/dev/null || true)
          if [ "$existing_id" != "$BUNDLE_ID" ]; then
              echo "error: $TARGET exists and isn't AppTraf — refusing to clobber" >&2
              exit 1
          fi
      fi

      rm -rf "$TARGET"
      cp -R "$SOURCE" "$TARGET"
      [ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$TARGET" >/dev/null 2>&1 || true
      /usr/bin/mdimport "$TARGET" >/dev/null 2>&1 || true

      echo "Installed: $TARGET"
    SH
    (bin/"apptraf-install-app").chmod 0755
  end

  def caveats
    <<~EOS
      The GUI bundle is at:
        #{opt_prefix}/AppTraf.app

      To make AppTraf appear in Spotlight, Launchpad and Finder, run once after
      install (and after every `brew upgrade`):
        apptraf-install-app

      Or just open the UI from any terminal:
        apptraf
    EOS
  end

  service do
    run [opt_bin/"apptrafd"]
    keep_alive true
    log_path var/"log/apptraf.log"
    error_log_path var/"log/apptraf.log"
    process_type :background
  end

  test do
    assert_path_exists bin/"apptrafd"
    assert_path_exists bin/"apptraf"
    assert_path_exists bin/"apptraf-install-app"
    assert_path_exists prefix/"AppTraf.app/Contents/MacOS/AppTraf"
    assert_path_exists prefix/"AppTraf.app/Contents/Info.plist"
    assert_path_exists prefix/"AppTraf.app/Contents/Resources/AppTraf.icns"

    plist = (prefix/"AppTraf.app/Contents/Info.plist").read
    assert_match "com.hexstyle.apptraf", plist
    assert_match version.to_s, plist
  end
end
