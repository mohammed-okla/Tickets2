import React from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { useLanguage } from '@/contexts/LanguageContext'
import { AlertTriangle, Search, Filter, MessageSquare } from 'lucide-react'

export default function DisputesPage() {
  const { t } = useLanguage()

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">{t('disputeManagement')}</h1>
          <p className="text-muted-foreground">{t('handleUserDisputesAndComplaints')}</p>
        </div>
        <div className="flex space-x-2">
          <Button variant="outline">
            <Search className="h-4 w-4 mr-2" />
            {t('searchDisputes')}
          </Button>
          <Button variant="outline">
            <Filter className="h-4 w-4 mr-2" />
            {t('filterDisputes')}
          </Button>
        </div>
      </div>

      {/* Placeholder Content */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <AlertTriangle className="h-5 w-5" />
            <span>{t('disputeManagement')}</span>
          </CardTitle>
          <CardDescription>{t('featureInDevelopment')}</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8">
            <MessageSquare className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
            <h3 className="text-lg font-medium">{t('disputesComingSoon')}</h3>
            <p className="text-muted-foreground">{t('disputesFeatureDescription')}</p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}