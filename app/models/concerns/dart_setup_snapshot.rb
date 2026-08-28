module DartSetupSnapshot
  extend ActiveSupport::Concern

  def snapshot_attributes
    {
      "manufacturer" => manufacturer,
      "manufacturer_label" => manufacturer_label,
      "weight_g" => weight_g.to_s,
      "shaft_type" => shaft_type,
      "shaft_type_label" => shaft_type_label,
      "shaft_length_mm" => shaft_length_mm,
      "point_length_mm" => point_length_mm
    }
  end

  def fingerprint
    Digest::SHA256.hexdigest(snapshot_attributes.except("manufacturer_label", "shaft_type_label").to_json).first(16)
  end

  def display_summary
    "#{manufacturer_label} · #{weight_g.to_s.sub(/\.0$/, '')}g · #{shaft_type_label} · #{shaft_length_mm}mm shaft · #{point_length_mm}mm point"
  end

  def manufacturer_label
    self.class::MANUFACTURER_LABELS.fetch(manufacturer, manufacturer.to_s.humanize)
  end

  def shaft_type_label
    shaft_type.to_s.humanize
  end
end
