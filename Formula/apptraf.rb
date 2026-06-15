class Apptraf < Formula
  desc "Lightweight per-app network traffic tracker for macOS"
  homepage "https://github.com/hexstyle/apptraf"
  url "https://github.com/hexstyle/apptraf.git",
      tag:      "v0.1.1",
      revision: "0b7d8ba3af584c4ed0c1fb0318f9749c6964b8a2"
  license "MIT"
  head "https://github.com/hexstyle/apptraf.git", branch: "main"

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
    assert_path_exists bin/"apptrafd"
    assert_path_exists bin/"apptraf"
  end
end
