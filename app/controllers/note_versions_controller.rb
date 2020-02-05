class NoteVersionsController < ApplicationController
  respond_to :html, :xml, :json

  def index
    @note_versions = NoteVersion.paginated_search(params)
    respond_with(@note_versions)
  end

  def show
    @note_version = NoteVersion.find(params[:id])
    respond_with(@note_version) do |format|
      format.html { redirect_to note_versions_path(search: { note_id: @note_version.note_id }) }
    end
  end
end
