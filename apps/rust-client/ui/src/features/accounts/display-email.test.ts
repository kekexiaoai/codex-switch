import { describe, expect, it } from "vitest";
import { displayEmail } from "./display-email";

describe("displayEmail", () => {
  it("uses full email when setting is enabled and email exists", () => {
    expect(
      displayEmail(
        {
          email: "alice@example.com",
          emailMask: "a••••@example.com",
        },
        true,
      ),
    ).toBe("alice@example.com");
  });

  it("falls back to masked email when setting is disabled", () => {
    expect(
      displayEmail(
        {
          email: "alice@example.com",
          emailMask: "a••••@example.com",
        },
        false,
      ),
    ).toBe("a••••@example.com");
  });
});
