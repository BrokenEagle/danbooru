class ArtistUrlsController < ApplicationController
  respond_to :js, :json, :xml, :html
  before_action :member_only, except: [:index]

  def index
    @artist_urls = ArtistUrl.includes({artist: [:urls]}).paginated_search(params)
    #respond_with(@artist_urls)
    respond_with(@artist_urls) do |format|
      #binding.pry
      #format.json { render json: @artist_urls.to_json(include: "artist") }
      format.json { render json: @artist_urls.to_json(format_params) }
      #format.json { render json: @artist_urls.to_json(render_params) }
      format.xml { render xml: @artist_urls.to_xml(format_params) }
    end
  end

  def update
    @artist_url = ArtistUrl.find(params[:id])
    @artist_url.update(artist_url_params)
    respond_with(@artist_url)
  end

  private

  def format_params
    @format_params ||= begin
      #binding.pry
      if params[:only]
        param_hash = SerializableParameters.process_only(params[:only],@artist_urls)
      else
        param_hash = {include: [:artist]}
      end
      if request.format.symbol == :xml
        param_hash[:root] = "artist-urls"
      end
      param_hash
    end
  end

  def artist_url_params
    permitted_params = %i[is_active]

    params.fetch(:artist_url, {}).permit(permitted_params)
  end
end
