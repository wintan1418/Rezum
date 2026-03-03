class SitemapController < ApplicationController
  def index
    @articles = Article.published.recent
    respond_to do |format|
      format.xml
    end
  end
end
