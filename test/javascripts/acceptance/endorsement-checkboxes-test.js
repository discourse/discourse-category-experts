import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import categories from "../category-expert-categories";

acceptance(
  "Discourse Category Experts - No existing endorsements",
  function (needs) {
    needs.user();
    needs.settings({ enable_category_experts: true });
    needs.site({ categories });

    needs.pretender((server, helper) => {
      let cardResponse = JSON.parse(
        JSON.stringify(userFixtures["/u/charlie/card.json"])
      );
      cardResponse.user.category_expert_endorsements = [];
      server.get("/u/charlie/card.json", () => helper.response(cardResponse));
      server.get("/category-experts/endorsable-categories/charlie.json", () =>
        helper.response({
          categories: [
            { id: 517, name: "Some Category" },
            { id: 10, name: "A different one" },
          ],
          extras: { remaining_endorsements: 10 },
        })
      );
    });

    test("It allows the current user to endorse another via the user card", async (assert) => {
      await visit("/t/internationalization-localization/280");
      await click(".topic-map__users-trigger");
      await click('a[data-user-card="charlie"]');

      await click(".category-expert-endorse-btn");

      let checkboxRows = queryAll(".category-experts-endorsement-row");
      assert.equal(checkboxRows.length, 2);

      let saveBtn = query(".category-endorsement-save");
      assert.equal(saveBtn.disabled, true);

      await click(checkboxRows[0]);
      assert.equal(saveBtn.disabled, false);
    });
  }
);

acceptance("Discourse Category Experts - Has endorsement", function (needs) {
  needs.user();
  needs.settings({ enable_category_experts: true });
  needs.site({ categories });

  needs.pretender((server, helper) => {
    let cardResponse = JSON.parse(
      JSON.stringify(userFixtures["/u/charlie/card.json"])
    );
    cardResponse.user.category_expert_endorsements = [
      {
        category_id: 517,
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
    server.get("/category-experts/endorsable-categories/charlie.json", () =>
      helper.response({
        categories: [
          { id: 517, name: "Some Category" },
          { id: 10, name: "A different one" },
        ],
        extras: { remaining_endorsements: 10 },
      })
    );
  });

  test("It shows the endorse button when the current user hasn't endorsed the user yet", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click(".topic-map__users-trigger");
    await click('a[data-user-card="charlie"]');

    assert.equal(queryAll(".category-expert-existing-endorsements").length, 1);

    await click(".category-expert-endorse-edit");

    let checkboxes = queryAll(".category-experts-endorsement-row input");
    assert.equal(checkboxes.length, 2);

    assert.equal(checkboxes[0].disabled, true);
    assert.equal(checkboxes[1].disabled, false);

    let saveBtn = query(".category-endorsement-save");
    assert.equal(saveBtn.disabled, true);

    await click(checkboxes[1]);
    assert.equal(saveBtn.disabled, false);
  });
});

acceptance(
  "Discourse Category Experts - No endorsements remaining",
  function (needs) {
    needs.user();
    needs.settings({ enable_category_experts: true });
    needs.site({ categories });

    needs.pretender((server, helper) => {
      let cardResponse = JSON.parse(
        JSON.stringify(userFixtures["/u/charlie/card.json"])
      );
      cardResponse.user.category_expert_endorsements = [];
      server.get("/u/charlie/card.json", () => helper.response(cardResponse));
      server.get("/category-experts/endorsable-categories/charlie.json", () =>
        helper.response({
          categories: [
            { id: 517, name: "Some Category" },
            { id: 10, name: "A different one" },
          ],
          extras: { remaining_endorsements: 0 },
        })
      );
    });

    test("shows the out of endorsements alert instead of the save button", async (assert) => {
      await visit("/t/internationalization-localization/280");
      await click(".topic-map__users-trigger");
      await click('a[data-user-card="charlie"]');

      await click(".category-expert-endorse-btn");

      assert.notOk(exists(".category-endorsement-save"));
      assert.ok(exists(".out-of-endorsements-alert"));
    });
  }
);
