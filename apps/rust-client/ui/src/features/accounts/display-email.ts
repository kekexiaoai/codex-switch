export function displayEmail(
  account: { email?: string | null; emailMask: string },
  showFullEmail: boolean,
) {
  if (showFullEmail && account.email) {
    return account.email;
  }

  return account.emailMask;
}
