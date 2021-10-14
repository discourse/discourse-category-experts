export default {
  shouldRender(args) {
    return !!args.user.category_expert_endorsements;
  },
};
