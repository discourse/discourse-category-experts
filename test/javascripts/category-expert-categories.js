export default [
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
