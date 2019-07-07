class Warning < Tag
  NAME = ArchiveConfig.WARNING_CATEGORY_NAME

  DISPLAY_NAME_MAPPING = {
    ArchiveConfig.WARNING_DEFAULT_TAG_NAME => ArchiveConfig.WARNING_DEFAULT_TAG_DISPLAY_NAME,
    ArchiveConfig.WARNING_NONE_TAG_NAME => ArchiveConfig.WARNING_NONE_TAG_DISPLAY_NAME
  }.freeze

  def self.warning_tags
    Set[ArchiveConfig.WARNING_DEFAULT_TAG_NAME,
        ArchiveConfig.WARNING_NONE_TAG_NAME,
        ArchiveConfig.WARNING_VIOLENCE_TAG_NAME,
        ArchiveConfig.WARNING_DEATH_TAG_NAME,
        ArchiveConfig.WARNING_NONCON_TAG_NAME,
        ArchiveConfig.WARNING_CHAN_TAG_NAME]
  end

  def self.warning?(warning)
    warning_tags.include? warning
  end

  def display_name
    DISPLAY_NAME_MAPPING[name] || name
  end
end
