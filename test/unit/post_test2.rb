require 'test_helper'

class PostTest < ActiveSupport::TestCase
  def self.assert_invalid_tag(tag_name)
    should "not allow '#{tag_name}' to be tagged" do
      post = build(:post, tag_string: "touhou #{tag_name}")

      assert(post.valid?)
      assert_equal("touhou", post.tag_string)
      assert_equal(1, post.warnings[:base].grep(/Couldn't add tag/).count)
    end
  end

  def setup
    super

    travel_to(2.weeks.ago) do
      @user = FactoryBot.create(:user)
    end
    @builder = create(:builder_user)
    @admin = create(:admin_user)
    CurrentUser.user = @user
    CurrentUser.ip_addr = "127.0.0.1"
  end

  def teardown
    super

    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end



  context "Deletion:" do

    context "Deleting a post" do

      context "that is status locked" do
        setup do
          @post = FactoryBot.create(:post)
          CurrentUser.scoped(@admin) do
            @lock = create(:post_lock, post: @post, creator: @admin, status_lock: true)
          end
        end

        should "fail" do
          @post.delete!("test")
          assert_equal(["Is status locked ; cannot delete post"], @post.errors.full_messages)
          assert_equal(1, Post.where("id = ?", @post.id).count)
        end
      end

    end
  end

  context "Moderation:" do

    context "A deleted post" do
      setup do
        @post = FactoryBot.create(:post, :is_deleted => true)
      end

      context "that is status locked" do
        setup do
          @lock = create(:post_lock, post: @post, creator: @admin, status_lock: true)
        end

        should "not allow undeletion" do
          approval = @post.approve!
          assert_equal(["Post is locked and cannot be approved"], approval.errors.full_messages)
          assert_equal(true, @post.is_deleted?)
        end
      end

    end

    context "A status locked post" do
      setup do
        @post = FactoryBot.create(:post)
        @lock = create(:post_lock, post: @post, creator: @admin, status_lock: true)
      end

      should "not allow new flags" do
        assert_raises(PostFlag::Error) do
          @post.flag!("wrong")
        end
      end

      should "not allow new appeals" do
        @appeal = build(:post_appeal, post: @post)

        assert_equal(false, @appeal.valid?)
        assert_includes(@appeal.errors.full_messages, "Post is locked and cannot be appealed")
      end

      should "not allow approval" do
        approval = @post.approve!
        assert_includes(approval.errors.full_messages, "Post is locked and cannot be approved")
      end
    end

  end

  context "Updating:" do

    context "A rating locked post" do
      setup do
        @post = FactoryBot.create(:post)
        create(:post_lock, post: @post, creator: @builder, rating_lock: true)
      end

      should "not allow values S, safe, derp" do
        ["S", "safe", "derp"].each do |rating|
          @post.rating = rating
          assert(!@post.valid?)
        end
      end

      should "not allow values s, e" do
        ["s", "e"].each do |rating|
          @post.rating = rating
          assert(!@post.valid?)
        end
      end
    end

  end


  context "Tagging:" do
    context "A post" do
      setup do
        @post = FactoryBot.create(:post)
      end

      context "tagged with a metatag" do



        context "for a parent" do
          setup do
            @parent = FactoryBot.create(:post)
          end

          context "that is locked" do
            should "not change the parent" do
              create(:post_lock, post: @post, creator: @builder, parent_lock: true)

              @post.update(:tag_string => "parent:#{@parent.id}")

              assert(@post.invalid?)
              assert_not_equal(@parent.id, @post.reload.parent_id)
            end
          end
        end



        context "for a rating" do
          context "that is locked" do
            should "not change the rating" do
              create(:post_lock, post: @post, creator: @builder, rating_lock: true)

              @post.update(:tag_string => "rating:e")

              assert(@post.invalid?)
              assert_not_equal("e", @post.reload.rating)
            end
          end
        end



        context "for a pool" do

          context "when the post is pool locked" do
            setup do
              @pool1 = FactoryBot.create(:pool)
              @pool2 = FactoryBot.create(:pool)
              @post.add_pool!(@pool1)
              CurrentUser.scoped(@builder) do
                create(:post_lock, post: @post, pools_lock: true)
              end
            end

            should "not add the post" do
              @post.update(tag_string: "aaa pool:#{@pool2.id}")
              assert_includes(@post.warnings.full_messages, "Pools are locked for this post and cannot be added or removed")
            end

            should "not remove the post" do
              @post.update(tag_string: "bbb -pool:#{@pool1.id}")
              assert_includes(@post.warnings.full_messages, "Pools are locked for this post and cannot be added or removed")
            end
          end

        end


        context "for a source" do
          context "that is locked" do
            should "not change the source" do
              create(:post_lock, post: @post, creator: @builder, source_lock: true)

              @post.update(:tag_string => "source:foo_blah")

              assert(@post.invalid?)
              assert_not_equal("source:foo_blah", @post.reload.source)
            end
          end
        end



        context "of" do
          setup do
            @moderator = FactoryBot.create(:moderator_user)
            @admin = FactoryBot.create(:admin_user)
          end

          PostLock::ALL_TYPES.each do |type|
            context "locked:#{type}" do
              context "by a member" do
                should "not lock the #{type}" do
                  assert_raises(User::PrivilegeError) { @post.update(:tag_string => "locked:#{type}") }
                  assert_equal(false, @post.send("has_active_#{type}_lock"))
                end
              end

              context "by a #{(type == "status" ? "admin" : "moderator")}" do
                should "lock/unlock the #{type}" do
                  @selected_user = (type == "status" ? @admin : @moderator)
                  CurrentUser.scoped(@selected_user) do
                    @post.update(:tag_string => "locked:#{type}")
                    assert_equal(true, @post.send("has_active_#{type}_lock"))

                    @post.update(:tag_string => "-locked:#{type}")
                    assert_equal(false, @post.send("has_active_#{type}_lock"))
                  end
                end
              end
            end
          end

          context "locked:all/none" do
            context "by an moderator/admin" do
              should "lock/unlock the permitted locks" do
                CurrentUser.scoped(@admin) do
                  @post.update(:tag_string => "locked:all")
                  assert_equal(true, @post.send("has_active_tags_lock"))
                  assert_equal(true, @post.send("has_active_status_lock"))
                end

                CurrentUser.scoped(@moderator) do
                  @post.update(:tag_string => "locked:none")
                  assert_equal(false, @post.send("has_active_tags_lock"))
                  assert_equal(true, @post.send("has_active_status_lock"))
                end
              end
            end
          end

        end

      end


      context "with a tags lock" do
        should "not change the tags" do
          create(:post_lock, post: @post, creator: @builder, tags_lock: true)

          @post.update(:tag_string => "foo bar")

          assert(@post.invalid?)
          assert_not_equal("foo bar", @post.reload.tag_string)
        end
      end


    end
  end



  context "Reverting: " do
    context "a post that is tags locked" do
      setup do
        @post = FactoryBot.create(:post, tag_string: "foo first")
        travel(2.hours) do
          @post.update(tag_string: "-foo last")
          @lock = create(:post_lock, post: @post, creator: @builder, tags_lock: true)
        end
      end

      should "not revert the tags" do
        assert_raises ActiveRecord::RecordInvalid do
          @post.revert_to!(@post.versions.first)
        end

        assert_equal(["Tags are locked and cannot be changed."], @post.errors.full_messages)
        assert_equal(@post.versions.last.tags, @post.reload.tag_string)
      end

      should "revert the tags after unlocking" do
        @lock.update(tags_lock: false)
        @post.update(tag_string: "fuu bar")
        assert_nothing_raised do
          @post.revert_to!(@post.versions.first)
        end

        assert(@post.valid?)
        assert_equal(@post.versions.first.tags, @post.tag_string)
      end
    end


    context "a post that is parent locked" do
      setup do
        @parent1 = FactoryBot.create(:post)
        @parent2 = FactoryBot.create(:post)
        @post = FactoryBot.create(:post, parent_id: @parent1.id)
        travel(2.hours) do
          @post.update(parent_id: @parent2.id)
          @lock = create(:post_lock, post: @post, creator: @builder, parent_lock: true)
        end
      end

      should "not revert the parent" do
        assert_raises ActiveRecord::RecordInvalid do
          @post.revert_to!(@post.versions.first)
        end

        assert_equal(["Parent ID is locked and cannot be changed."], @post.errors.full_messages)
        assert_equal(@post.versions.last.parent_id, @post.reload.parent_id)
      end

      should "revert the parent after unlocking" do
        @lock.update(parent_lock: false)
        @post.update(parent_id: @parent2.id)
        assert_nothing_raised do
          @post.revert_to!(@post.versions.first)
        end

        assert(@post.valid?)
        assert_equal(@post.versions.first.parent_id, @post.parent_id)
      end
    end

    context "a post that is rating locked" do
      setup do
        @post = FactoryBot.create(:post, :rating => "s")
        travel(2.hours) do
          @post.update(rating: "q")
          @lock = create(:post_lock, post: @post, creator: @builder, rating_lock: true)
        end
      end

      should "not revert the rating" do
        assert_raises ActiveRecord::RecordInvalid do
          @post.revert_to!(@post.versions.first)
        end

        assert_equal(["Rating is locked and cannot be changed."], @post.errors.full_messages)
        assert_equal(@post.versions.last.rating, @post.reload.rating)
      end

      should "revert the rating after unlocking" do
        @lock.update(rating_lock: false)
        @post.update(rating: "e")
        assert_nothing_raised do
          @post.revert_to!(@post.versions.first)
        end

        assert(@post.valid?)
        assert_equal(@post.versions.first.rating, @post.rating)
      end
    end

    context "a post that is source locked" do
      setup do
        @post = FactoryBot.create(:post, source: "foo_first")
        travel(2.hours) do
          @post.update(source: "foo_last")
          @lock = create(:post_lock, post: @post, creator: @builder, source_lock: true)
        end
      end

      should "not revert the source" do
        assert_raises ActiveRecord::RecordInvalid do
          @post.revert_to!(@post.versions.first)
        end

        assert_equal(["Source is locked and cannot be changed."], @post.errors.full_messages)
        assert_equal(@post.versions.last.source, @post.reload.source)
      end

      should "revert the source after unlocking" do
        @lock.update(source_lock: false)
        @post.update(source: "foo_blah")
        assert_nothing_raised do
          @post.revert_to!(@post.versions.first)
        end

        assert(@post.valid?)
        assert_equal(@post.versions.first.source, @post.source)
      end
    end


  end




end


