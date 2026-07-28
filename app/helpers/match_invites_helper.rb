module MatchInvitesHelper
  def qr_code_svg(url)
    Rails.cache.fetch(["match-invite-qr-svg", url], expires_in: Match::INVITE_TTL) do
      RQRCode::QRCode.new(url).as_svg(
        color: "000",
        shape_rendering: "crispEdges",
        module_size: 5,
        standalone: true,
        use_path: true
      )
    end.html_safe
  end
end
