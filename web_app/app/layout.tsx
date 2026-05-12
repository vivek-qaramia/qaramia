import type { Metadata } from "next";
import { Geist } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "@/components/auth/auth-provider";
import { Navbar } from "@/components/ui/navbar";
import { AgoraErrorSuppressor } from "@/components/ui/agora-error-suppressor";

const geist = Geist({ subsets: ["latin"], variable: "--font-geist" });

export const metadata: Metadata = {
  title: "Streamr — Watch Live. Go Live.",
  description: "Live streaming social platform",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${geist.variable} h-full`}>
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
