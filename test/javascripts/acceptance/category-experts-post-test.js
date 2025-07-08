import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";

const groupName = "some-group";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Discourse Category Experts - Posts - Auto-approved (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        enable_category_experts: true,
        category_experts_posts_require_approval: false,
        glimmer_post_stream_mode: postStreamMode,
      });

      needs.pretender((server, helper) => {
        // deep clone
        let topicResponse = JSON.parse(
          JSON.stringify(topicFixtures["/t/2480/1.json"])
        );
        topicResponse.post_stream.posts[2].category_expert_approved_group =
          groupName;
        server.get("/t/2480.json", () => helper.response(topicResponse));

        let cardResponse = JSON.parse(
          JSON.stringify(userFixtures["/u/charlie/card.json"])
        );
        cardResponse.user.username = "normal_user";
        cardResponse.user.category_expert_endorsements = [];
        cardResponse.user.topic_post_count = { 2480: 2 };
        server.get("/u/normal_user/card.json", () =>
          helper.response(cardResponse)
        );
      });

      test("Posts with category_expert_approved have the correct classes", async function (assert) {
        await visit("/t/topic-for-group-moderators/2480");

        const articles = queryAll(".topic-post article.onscreen-post");
        const lastArticle = articles[articles.length - 1];

        assert.ok(lastArticle.classList.contains("category-expert-post"));
        assert.ok(
          lastArticle.classList.contains(`category-expert-${groupName}`)
        );

        await click(lastArticle.querySelector("button.show-more-actions"));

        assert.notOk(exists(".post-controls .unapprove-category-expert-post"));
      });

      test("Filter posts by user works", async function (assert) {
        await visit("/t/topic-for-group-moderators/2480");
        await click("article#post_2 .trigger-user-card a");
        await click(".usercard-controls .btn-default");
        assert.equal(queryAll(".topic-post").length, 3);
      });
    }
  );

  acceptance(
    `Discourse Category Experts - Posts - Need approved (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        enable_category_experts: true,
        category_experts_posts_require_approval: true,
        glimmer_post_stream_mode: postStreamMode,
      });

      needs.pretender((server, helper) => {
        // deep clone
        let topicResponse = JSON.parse(
          JSON.stringify(topicFixtures["/t/2480/1.json"])
        );
        topicResponse.post_stream.posts[1].needs_category_expert_approval = true;
        topicResponse.post_stream.posts[1].can_manage_category_expert_posts = true;

        topicResponse.post_stream.posts[2].category_expert_approved_group =
          groupName;
        topicResponse.post_stream.posts[2].can_manage_category_expert_posts = true;

        server.get("/t/2480.json", () => helper.response(topicResponse));
        server.post("/category-experts/unapprove", () => helper.response({}));
        server.post("/category-experts/approve", () =>
          helper.response({
            group_name: groupName,
          })
        );
      });

      test("The unapprove button is present and works for approved posts", async function (assert) {
        await visit("/t/topic-for-group-moderators/2480");

        const articles = queryAll(".topic-post article.onscreen-post");
        const lastArticle = articles[articles.length - 1];

        assert.ok(lastArticle.classList.contains("category-expert-post"));
        assert.ok(
          lastArticle.classList.contains(`category-expert-${groupName}`)
        );

        await click(lastArticle.querySelector("button.show-more-actions"));
        await click(".post-controls .unapprove-category-expert-post");

        assert.notOk(lastArticle.classList.contains("category-expert-post"));
      });

      test("The approve button is present and works for unapproved posts by category experts", async function (assert) {
        await visit("/t/topic-for-group-moderators/2480");

        const articles = queryAll(".topic-post article.onscreen-post");
        const article = articles[articles.length - 2];

        assert.notOk(article.classList.contains("category-expert-post"));
        assert.notOk(
          article.classList.contains(`category-expert-${groupName}`)
        );

        await click(
          article.querySelector(".post-controls .approve-category-expert-post")
        );

        assert.ok(article.classList.contains("category-expert-post"));
        assert.ok(article.classList.contains(`category-expert-${groupName}`));
      });
    }
  );
});
