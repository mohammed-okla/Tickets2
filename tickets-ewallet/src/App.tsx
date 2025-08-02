import React from 'react'
import { AuthProvider } from '@/contexts/AuthContext'
import { LanguageProvider } from '@/contexts/LanguageContext'
import { ThemeProvider } from '@/contexts/ThemeContext'
import AppRouter from '@/components/common/AppRouter'
import { Toaster } from '@/components/ui/sonner'
import '@/index.css'

export default function App() {
  return (
    <ThemeProvider>
      <LanguageProvider>
        <AuthProvider>
          <div className="min-h-screen bg-background">
            <AppRouter />
            <Toaster richColors position="top-right" />
          </div>
        </AuthProvider>
      </LanguageProvider>
    </ThemeProvider>
  )
}
