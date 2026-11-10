import { openIce } from "./open";

export default async function Command() {
  await openIce("focus", "Ice++ focus mode");
}
