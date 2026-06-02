export const metadata = {
  title: "DropCity Terms of Service",
  description: "Terms of Service for DropCity client and courier apps",
};

const sections = [
  {
    title: "1. Using DropCity",
    body:
      "DropCity connects senders with couriers travelling along compatible routes. You agree to provide accurate parcel, pickup, dropoff, and contact details when using the platform.",
  },
  {
    title: "2. Parcels and Prohibited Items",
    body:
      "You must not send illegal, hazardous, perishable, stolen, or restricted goods. DropCity may reject, suspend, or investigate any delivery that appears unsafe or non-compliant.",
  },
  {
    title: "3. Identity and Verification",
    body:
      "Client and courier accounts may require identity, phone, and profile verification. You are responsible for keeping your credentials secure and your account information current.",
  },
  {
    title: "4. Privacy and Tracking",
    body:
      "DropCity uses privacy-preserving delivery progress where possible. Live courier location is not exposed to clients unless required for safety, support, dispute resolution, or lawful compliance.",
  },
  {
    title: "5. Pickup, Dropoff, and PINs",
    body:
      "Secure handoff flows may use one-time PINs, proximity checks, photos, and timestamps. Do not share delivery PINs except with the intended handoff participant.",
  },
  {
    title: "6. Pricing and Disputes",
    body:
      "Recommended prices are estimates. Couriers and clients may agree final delivery terms where the app allows it. Report delivery issues promptly through DropCity support channels.",
  },
  {
    title: "7. Updates",
    body:
      "These terms may be updated as DropCity evolves. Continued use of the platform after changes means you accept the updated terms.",
  },
];

export default function TermsPage() {
  return (
    <main className="min-h-screen bg-[#F8F9FA] px-5 py-8 text-[#2F4F4F]">
      <article className="mx-auto max-w-3xl rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="mb-8 flex items-center gap-3">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#008080] text-xl font-black text-white">
            D
          </div>
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.24em] text-[#94A3B8]">DropCity</p>
            <h1 className="text-2xl font-bold text-[#2F4F4F]">Terms of Service</h1>
          </div>
        </div>

        <p className="mb-6 leading-7 text-slate-600">
          These Terms explain the basic rules for using DropCity. They are written for mobile viewing
          and may be expanded before production launch with jurisdiction-specific legal language.
        </p>

        <div className="space-y-5">
          {sections.map((section) => (
            <section key={section.title} className="rounded-2xl border border-slate-100 bg-[#F8F9FA] p-4">
              <h2 className="mb-2 text-base font-bold text-[#008080]">{section.title}</h2>
              <p className="text-sm leading-6 text-slate-600">{section.body}</p>
            </section>
          ))}
        </div>

        <p className="mt-8 text-xs leading-5 text-[#94A3B8]">
          Last updated: June 2, 2026. Contact DropCity Support for questions about these terms.
        </p>
      </article>
    </main>
  );
}
