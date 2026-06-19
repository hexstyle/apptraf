class Apptraf < Formula
  desc "Lightweight per-app network traffic tracker for macOS"
  homepage "https://github.com/hexstyle/apptraf"
  url "https://github.com/hexstyle/apptraf.git",
      tag:      "v0.1.2",
      revision: "9ff47fecd6cffdcd4ee9cf9146c38b655c3e0ea4"
  license "MIT"
  head "https://github.com/hexstyle/apptraf.git", branch: "main"

  depends_on :macos

  APPLICATIONS_DIR = Pathname.new("/Applications").freeze

  def install
    system "scripts/build-app.sh", version.to_s
    prefix.install ".build/release/AppTraf.app"
    bin.install ".build/release/apptrafd"

    (bin/"apptraf").write <<~SH
      #!/bin/sh
      exec /usr/bin/open -a "#{opt_prefix}/AppTraf.app" "$@"
    SH
    (bin/"apptraf").chmod 0755
  end

  def post_install
    source = opt_prefix/"AppTraf.app"
    target = APPLICATIONS_DIR/"AppTraf.app"

    return if !APPLICATIONS_DIR.directory? || !APPLICATIONS_DIR.writable?
    return if target.exist? && !target.symlink?

    target.delete if target.symlink?
    target.make_symlink(source)
  rescue Errno::EACCES, Errno::EPERM
    # /Applications wasn't writable — fall through to caveats.
  end

  def caveats
    target = APPLICATIONS_DIR/"AppTraf.app"
    if target.symlink? && target.readlink == opt_prefix/"AppTraf.app"
      <<~EOS
        AppTraf.app is linked into /Applications and available via
        Spotlight, Launchpad and Finder. Launch from terminal: apptraf
      EOS
    else
      <<~EOS
        The GUI bundle is at:
          #{opt_prefix}/AppTraf.app

        /Applications wasn't writable, so it wasn't symlinked automatically.
        To make it appear in Spotlight, Launchpad and Finder:
          ln -sfn "#{opt_prefix}/AppTraf.app" /Applications/AppTraf.app

        Launch from terminal: apptraf
      EOS
    end
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
    assert_path_exists prefix/"AppTraf.app/Contents/MacOS/AppTraf"
    assert_path_exists prefix/"AppTraf.app/Contents/Info.plist"
    assert_path_exists prefix/"AppTraf.app/Contents/Resources/AppTraf.icns"

    plist = (prefix/"AppTraf.app/Contents/Info.plist").read
    assert_match "com.hexstyle.apptraf", plist
    assert_match version.to_s, plist
  end
end
