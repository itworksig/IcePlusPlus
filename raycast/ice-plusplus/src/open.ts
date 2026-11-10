import { showHUD } from "@raycast/api";
import { execFile } from "child_process";

export async function openIce(command: string, title: string) {
  await new Promise<void>((resolve, reject) => {
    execFile("open", [`iceplusplus://${command}`], (error) => {
      if (error) {
        reject(error);
      } else {
        resolve();
      }
    });
  });
  await showHUD(title);
}
