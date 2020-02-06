class ArtistVersion < ApplicationRecord
  array_attribute :urls
  array_attribute :other_names

  belongs_to_updater
  belongs_to :artist

  module SearchMethods
    def search(params)
      q = super

      q = q.search_attributes(params, :updater, :is_active, :is_banned, :artist_id, :name, :group_name)

      if params[:order] == "name"
        q = q.order("artist_versions.name").default_order
      else
        q = q.apply_default_order(params)
      end

      q
    end
  end

  extend SearchMethods

  def previous
    ArtistVersion.where("artist_id = ? and created_at < ?", artist_id, created_at).order("created_at desc").first
  end

  def self.default_includes(params)
    if ["json", "xml"].include?(params[:format])
      {}
    else
      {updater: [], artist: [{urls: []}]}
    end
  end
end
