import type { Metadata } from "next";
import { Geist, Playfair_Display } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "@/components/auth/auth-provider";
import { Navbar } from "@/components/ui/navbar";
import { AgoraErrorSuppressor } from "@/components/ui/agora-error-suppressor";

const geist = Geist({ subsets: ["latin"], variable: "--font-geist" });
const playfair = Playfair_Display({
  subsets: ["latin"],
  variable: "--font-playfair",
  style: ["italic", "normal"],
  weight: ["500", "600", "700"],
});

export const metadata: Metadata = {
  title: "Qaramia — Live commerce, beloved",
  description: "Live streaming where every product mentioned — seen or heard — is a purchase opportunity",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${geist.variable} ${playfair.variable} h-full`}>
      <body className="min-h-full bg-black text-white antialiased">
        <AuthProvider>
          <AgoraErrorSuppressor />
          <Navbar />
          <main className="pt-14">{children}</main>
        </AuthProvider>
      </body>
    </html>
  );
}
