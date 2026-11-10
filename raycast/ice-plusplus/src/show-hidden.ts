import { openIce } from "./open";

export default async function Command() {
  await openIce("show-hidden", "Ice++ hidden items");
}
