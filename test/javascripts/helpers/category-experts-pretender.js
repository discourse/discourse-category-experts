export default function (helper) {
  this.get("/category-experts/retroactive-approval/:postId.json", () => {
    return helper.response({ can_be_approved: false });
  });
}
