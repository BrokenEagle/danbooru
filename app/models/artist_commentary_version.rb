class ArtistCommentaryVersion < ApplicationRecord
  belongs_to :post
  belongs_to_updater

  def self.search(params)
    q = super
    q = q.search_attributes(params, :post, :updater, :original_title, :original_description, :translated_title, :translated_description)
    q.apply_default_order(params)
  end

  def self.default_includes(params)
    if ["json", "xml"].include?(params[:format])
      {}
    else
      [{post: [:uploader]}, :updater]
    end
  end
end
