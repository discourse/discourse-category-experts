import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import userFixtures from "discourse/tests/fixtures/user-fixtures";

let categories = [
  {
    id: 5,
    name: "test accepting endorsements 1",
    slug: "test-accepting-endorsements-1",
    permission: null,
    custom_fields: {
      category_expert_group_ids: "1",
      category_accepting_endorsements: "true",
    },
    allowingCategoryExpertEndorsements: true,
  },
  {
    id: 6,
    name: "test accepting endorsements 2",
    slug: "test-accepting-endorsements-2",
    permission: null,
    custom_fields: {
      category_expert_group_ids: "2|3",
      category_accepting_endorsements: "true",
    },
    allowingCategoryExpertEndorsements: true,
  },
  {
    id: 7,
    name: "test not accepting endorsements",
    slug: "test-not-accepting-endorsements",
    permission: null,
  },
];

acceptance("Discourse Category Experts - No endorsements", function (needs) {
  needs.user();
  needs.settings({ enable_category_experts: true });
  needs.site({ categories });

  needs.pretender((server, helper) => {
    let cardResponse = Object.assign({}, userFixtures["/u/charlie/card.json"]);
    cardResponse.user.category_expert_endorsements = [];
    server.get("/u/charlie/card.json", () => helper.response(cardResponse));
  });

  test("It allows the current user to endorse another via the user card", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click('a[data-user-card="charlie"]');

    let endorseBtn = find(".category-expert-endorse-btn");
    assert.equal(endorseBtn.length, 1);

    await click(endorseBtn);

    let checkboxRows = find(".category-experts-endorsement-row");
    assert.equal(checkboxRows.length, 2);

    let saveBtn = find(".category-endorsement-save")[0];
    assert.equal(saveBtn.disabled, true);

    await click(checkboxRows[0]);
    assert.equal(saveBtn.disabled, false);
  });
});

acceptance("Discourse Category Experts - Has endorsement", function (needs) {
  needs.user();
  needs.settings({ enable_category_experts: true });
  needs.site({ categories });

  needs.pretender((server, helper) => {
    let cardResponse = Object.assign({}, userFixtures["/u/charlie/card.json"]);
    cardResponse.user.category_expert_endorsements = [
      {
        category_id: 5,
        endorsed_user_id: cardResponse.user.id,
        id: 1,
      },
      {
        category_id: 10, // invalid category_id. UI should ignore this!
        endorsed_user_id: cardResponse.user.id,
        id: 2,
      },
    ];
    server.get("/u/charlie/card.json", () => helper.response(cardResponse));
  });

  test("It shows the endorse button when the current user hasn't endorsed the user yet", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click('a[data-user-card="charlie"]');

    assert.equal(find(".category-expert-existing-endorsements").length, 1);

    await click(find(".endorse-link"));

    let checkboxes = find(".category-experts-endorsement-row input");
    assert.equal(checkboxes.length, 2);

    assert.equal(checkboxes[0].disabled, true);
    assert.equal(checkboxes[1].disabled, false);

    let saveBtn = find(".category-endorsement-save")[0];
    assert.equal(saveBtn.disabled, true);

    await click(checkboxes[1]);
    assert.equal(saveBtn.disabled, false);
  });
});
