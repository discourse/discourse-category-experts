import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import topicFixtures from "discourse/tests/fixtures/topic";

const groupName = "some-group";

acceptance(
  "Discourse Category Experts - Posts - Auto-approved",
  function (needs) {
    needs.user();
    needs.settings({
      enable_category_experts: true,
      category_experts_posts_require_approval: false,
    });

    needs.pretender((server, helper) => {
      let topicResponse = Object.assign({}, topicFixtures["/t/2480/1.json"]);
      topicResponse.post_stream.posts[2].category_expert_approved_group = groupName;
      server.get("/t/2480.json", () => helper.response(topicResponse));
    });

    test("Posts with category_expert_approved have the correct classes", async function (assert) {
      await visit("/t/topic-for-group-moderators/2480");

      const articles = queryAll(".topic-post article");
      const lastArticle = articles[articles.length - 1];

      assert.ok(lastArticle.classList.contains("category-expert-post"));
      assert.ok(lastArticle.classList.contains(`category-expert-${groupName}`));

      await click(lastArticle.querySelector("button.show-more-actions"));

      assert.notOk(exists(".widget-button.unapprove-category-expert-post"));
    });
  }
);

acceptance(
  "Discourse Category Experts - Posts - Need approved",
  function (needs) {
    needs.user();
    needs.settings({
      enable_category_experts: true,
      category_experts_posts_require_approval: true,
    });

    needs.pretender((server, helper) => {
      let topicResponse = Object.assign({}, topicFixtures["/t/2480/1.json"]);
      topicResponse.post_stream.posts[1].needs_category_expert_approval = true;
      topicResponse.post_stream.posts[1].can_manage_category_expert_posts = true;

      topicResponse.post_stream.posts[2].category_expert_approved_group = groupName;
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

      const articles = queryAll(".topic-post article");
      const lastArticle = articles[articles.length - 1];

      assert.ok(lastArticle.classList.contains("category-expert-post"));
      assert.ok(lastArticle.classList.contains(`category-expert-${groupName}`));

      await click(lastArticle.querySelector("button.show-more-actions"));

      const unapproveBtn = query(
        ".widget-button.unapprove-category-expert-post"
      );
      await click(unapproveBtn);

      assert.notOk(lastArticle.classList.contains("category-expert-post"));
    });

    test("The approve button is present and works for unapproved posts by category experts", async function (assert) {
      await visit("/t/topic-for-group-moderators/2480");

      const articles = queryAll(".topic-post article");
      const article = articles[articles.length - 2];

      assert.notOk(article.classList.contains("category-expert-post"));
      assert.notOk(article.classList.contains(`category-expert-${groupName}`));

      await click(article.querySelector("button.approve-category-expert-post"));

      assert.ok(article.classList.contains("category-expert-post"));
      assert.ok(article.classList.contains(`category-expert-${groupName}`));
    });
  }
);
