import { openIce } from "./open";

export default async function Command() {
  await openIce("hide-hidden", "Ice++ hid the hidden section");
}
