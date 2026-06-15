class Apptraf < Formula
  desc "Lightweight per-app network traffic tracker for macOS"
  homepage "https://github.com/hexstyle/apptraf"
  url "https://github.com/hexstyle/apptraf.git",
      tag:      "v0.1.0",
      revision: "PLACEHOLDER_REVISION"
  version "0.1.0"
  license "MIT"
  head "https://github.com/hexstyle/apptraf.git", branch: "main"

  depends_on xcode: ["14.0"] => :build
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/apptraf"
    bin.install ".build/release/apptrafd"
  end

  service do
    run [opt_bin/"apptrafd"]
    keep_alive true
    log_path var/"log/apptraf.log"
    error_log_path var/"log/apptraf.log"
    process_type :background
  end

  test do
    assert_predicate bin/"apptrafd", :exist?
    assert_predicate bin/"apptraf",  :exist?
  end
end
