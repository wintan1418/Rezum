module Admin
  class ArticlesController < BaseController
    before_action :set_article, only: [ :show, :edit, :update, :destroy, :toggle_publish ]

    def index
      @articles = Article.order(created_at: :desc)
      @articles = @articles.by_category(params[:category]) if params[:category].present?
      @published_count = Article.where(published: true).count
      @draft_count = Article.where(published: false).count
    end

    def show
      redirect_to edit_admin_article_path(@article)
    end

    def new
      @article = Article.new(published: false, reading_time: 5, author: "RezumFit Team")
    end

    def create
      @article = Article.new(article_params)
      @article.reading_time = estimate_reading_time(@article.content) if @article.content.present?

      if @article.save
        redirect_to admin_articles_path, notice: "Article created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @article.update(article_params)
        @article.update(reading_time: estimate_reading_time(@article.content)) if @article.content.present?
        redirect_to edit_admin_article_path(@article), notice: "Article updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @article.destroy
      redirect_to admin_articles_path, notice: "Article deleted."
    end

    def toggle_publish
      if @article.published?
        @article.update!(published: false)
        redirect_to admin_articles_path, notice: "\"#{@article.title}\" unpublished."
      else
        @article.update!(published: true, published_at: @article.published_at || Time.current)
        redirect_to admin_articles_path, notice: "\"#{@article.title}\" published!"
      end
    end

    private

    def set_article
      @article = Article.find(params[:id])
    end

    def article_params
      params.require(:article).permit(
        :title, :content, :excerpt, :category, :author,
        :meta_title, :meta_description, :featured_image_url,
        :published, :published_at, :reading_time, tags: []
      )
    end

    def estimate_reading_time(content)
      word_count = ActionController::Base.helpers.strip_tags(content).split.size
      [ (word_count / 200.0).ceil, 1 ].max
    end
  end
end
