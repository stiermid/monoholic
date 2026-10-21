# frozen_string_literal: true

require "github-pages"
require "webmock"

# Replace only the network response. The real remote-theme downloader must
# fetch, extract, and configure a ZIP of the checkout under the Pages stack.
download_url = "https://codeload.github.com/stiermid/monoholic/zip/pages-test"
WebMock.enable!
WebMock.disable_net_connect!
WebMock.stub_request(:get, download_url).to_return(
  status: 200,
  body: File.binread(ENV.fetch("MONOHOLIC_THEME_ARCHIVE")),
  headers: { "Content-Type" => "application/zip" }
)

Jekyll::Hooks.register :site, :post_read do |site|
  unless GitHubPages::Configuration.processed?(site) && site.safe
    raise "Consumer must use the native Pages configuration and safe mode"
  end
  unless site.theme.is_a?(Jekyll::RemoteTheme::Theme)
    raise "Consumer must load the ZIP through jekyll-remote-theme"
  end
  missing = GitHubPages::Plugins::DEFAULT_PLUGINS - site.config["plugins"]
  unless missing.empty?
    raise "Missing default Pages plugins: #{missing.join(', ')}"
  end
end

at_exit do
  if $!.nil? || ($!.is_a?(SystemExit) && $!.success?)
    WebMock.assert_requested(:get, download_url, times: 1)
  end
end
