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

// TODO (glimmer-post-menu): Remove this file when the post menu widget code is removed from core
acceptance(
  "Discourse Category Experts - Widget Post Menu - Posts - Auto-approved",
  function (needs) {
    needs.user();
    needs.settings({
      glimmer_post_menu_mode: "disabled",

      enable_category_experts: true,
      category_experts_posts_require_approval: false,
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
      assert.ok(lastArticle.classList.contains(`category-expert-${groupName}`));

      await click(lastArticle.querySelector("button.show-more-actions"));

      assert.notOk(exists(".widget-button.unapprove-category-expert-post"));
    });

    test("Filter posts by user works", async function (assert) {
      await visit("/t/topic-for-group-moderators/2480");
      await click("article#post_2 .trigger-user-card");
      await click(".usercard-controls .btn-default");
      assert.equal(queryAll(".topic-post").length, 3);
    });
  }
);

acceptance(
  "Discourse Category Experts - Widget Post Menu - Posts - Need approved",
  function (needs) {
    needs.user();
    needs.settings({
      glimmer_post_menu_mode: "disabled",

      enable_category_experts: true,
      category_experts_posts_require_approval: true,
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
      assert.ok(lastArticle.classList.contains(`category-expert-${groupName}`));

      await click(lastArticle.querySelector("button.show-more-actions"));
      await click(".widget-button.unapprove-category-expert-post");

      assert.notOk(lastArticle.classList.contains("category-expert-post"));
    });

    test("The approve button is present and works for unapproved posts by category experts", async function (assert) {
      await visit("/t/topic-for-group-moderators/2480");

      const articles = queryAll(".topic-post article.onscreen-post");
      const article = articles[articles.length - 2];

      assert.notOk(article.classList.contains("category-expert-post"));
      assert.notOk(article.classList.contains(`category-expert-${groupName}`));

      await click(article.querySelector("button.approve-category-expert-post"));

      assert.ok(article.classList.contains("category-expert-post"));
      assert.ok(article.classList.contains(`category-expert-${groupName}`));
    });
  }
);
