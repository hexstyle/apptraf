class Apptraf < Formula
  desc "Lightweight per-app network traffic tracker for macOS"
  homepage "https://github.com/hexstyle/apptraf"
  url "https://github.com/hexstyle/apptraf.git",
      tag:      "v0.1.0",
      revision: "b0638c9dace725c4dd07e2ec7ee98d72f3b7a1f8"
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
