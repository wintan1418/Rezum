class ArticlesController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def index
    @articles = Article.published.recent
    @articles = @articles.by_category(params[:category]) if params[:category].present?
    @categories = Article::CATEGORIES
  end

  def show
    @article = Article.published.friendly.find(params[:id])
    @related_articles = @article.related_articles(limit: 3)
  end
end
