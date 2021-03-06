require "test_helper"

class CommentComponentTest < ViewComponent::TestCase
  def render_comment(comment, current_user: User.anonymous, **options)
    as(current_user) do
      render_inline(CommentComponent.new(comment: comment, current_user: current_user, **options))
    end
  end

  context "The CommentComponent" do
    setup do
      @comment = as(create(:user)) { create(:comment) }
    end

    context "for a regular comment" do
      should "render for Anonymous" do
        render_comment(@comment, current_user: User.anonymous)

        assert_css("article#comment_#{@comment.id}")
      end

      should "render for a Member" do
        render_comment(@comment, current_user: create(:user))

        assert_css("article#comment_#{@comment.id}")
      end
    end

    context "for a comment with moderation reports" do
      should "show the report notice to moderators" do
        create(:moderation_report, model: @comment)
        render_comment(@comment, current_user: create(:moderator_user))

        assert_css(".moderation-report-notice")
      end

      should "not show the report notice to regular users" do
        render_comment(@comment, current_user: User.anonymous)

        assert_no_css(".moderation-report-notice")
      end
    end
  end
end
