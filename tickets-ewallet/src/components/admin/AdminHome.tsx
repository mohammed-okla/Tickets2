import React, { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { useAuth } from '@/contexts/AuthContext'
import { useLanguage } from '@/contexts/LanguageContext'
import { supabase } from '@/lib/supabase'
import { 
  Users,
  DollarSign,
  TrendingUp,
  AlertTriangle,
  Activity,
  CreditCard,
  Ticket,
  Building,
  Shield,
  Settings,
  Eye,
  EyeOff
} from 'lucide-react'

interface SystemStats {
  totalUsers: number
  activeUsers: number
  totalTransactions: number
  totalRevenue: number
  pendingDisputes: number
  systemUptime: number
  recentUsers: any[]
  recentTransactions: any[]
  usersByType: {
    passengers: number
    drivers: number
    merchants: number
    eventAdmins: number
  }
}

export default function AdminHome() {
  const { profile } = useAuth()
  const { t, language } = useLanguage()
  const [stats, setStats] = useState<SystemStats>({
    totalUsers: 0,
    activeUsers: 0,
    totalTransactions: 0,
    totalRevenue: 0,
    pendingDisputes: 0,
    systemUptime: 99.9,
    recentUsers: [],
    recentTransactions: [],
    usersByType: {
      passengers: 0,
      drivers: 0,
      merchants: 0,
      eventAdmins: 0
    }
  })
  const [isLoading, setIsLoading] = useState(true)
  const [showRevenue, setShowRevenue] = useState(true)

  useEffect(() => {
    if (profile) {
      fetchSystemStats()
    }
  }, [profile])

  const fetchSystemStats = async () => {
    try {
      setIsLoading(true)

      // Fetch users
      const { data: users, error: usersError } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false })

      if (usersError) throw usersError

      // Fetch transactions
      const { data: transactions, error: transactionsError } = await supabase
        .from('transactions')
        .select(`
          *,
          from_profile:profiles!transactions_from_user_id_fkey (
            full_name
          ),
          to_profile:profiles!transactions_to_user_id_fkey (
            full_name
          )
        `)
        .order('created_at', { ascending: false })
        .limit(10)

      if (transactionsError) throw transactionsError

      // Calculate stats
      const totalUsers = users?.length || 0
      const activeUsers = users?.filter(u => u.is_active).length || 0
      const totalTransactions = transactions?.length || 0
      const totalRevenue = transactions?.reduce((sum, t) => sum + t.amount, 0) || 0

      // Count users by type
      const usersByType = {
        passengers: users?.filter(u => u.user_type === 'passenger').length || 0,
        drivers: users?.filter(u => u.user_type === 'driver').length || 0,
        merchants: users?.filter(u => u.user_type === 'merchant').length || 0,
        eventAdmins: users?.filter(u => u.user_type === 'event_admin').length || 0
      }

      // Get recent users (last 5)
      const recentUsers = users?.slice(0, 5) || []

      setStats({
        totalUsers,
        activeUsers,
        totalTransactions,
        totalRevenue,
        pendingDisputes: 0, // TODO: Implement disputes
        systemUptime: 99.9, // Mock data
        recentUsers,
        recentTransactions: transactions?.slice(0, 5) || [],
        usersByType
      })
    } catch (error) {
      console.error('Error fetching system stats:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat(language === 'ar' ? 'ar-SY' : 'en-US', {
      style: 'currency',
      currency: 'SYP',
      minimumFractionDigits: 0
    }).format(amount)
  }

  const getUserTypeColor = (userType: string) => {
    switch (userType) {
      case 'passenger': return 'default'
      case 'driver': return 'secondary'
      case 'merchant': return 'outline'
      case 'event_admin': return 'destructive'
      case 'admin': return 'destructive'
      default: return 'secondary'
    }
  }

  const getTransactionStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'default'
      case 'pending': return 'secondary'
      case 'failed': return 'destructive'
      case 'cancelled': return 'outline'
      default: return 'secondary'
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">
            {t('systemDashboard')}
          </h1>
          <p className="text-muted-foreground">{t('systemOverviewAndManagement')}</p>
        </div>
        <div className="flex space-x-2">
          <Button variant="outline">
            <Settings className="h-4 w-4 mr-2" />
            {t('systemSettings')}
          </Button>
          <Button variant="outline">
            <Shield className="h-4 w-4 mr-2" />
            {t('securityPanel')}
          </Button>
        </div>
      </div>

      {/* System Status Alert */}
      <Card className="border-green-200 bg-green-50">
        <CardContent className="pt-6">
          <div className="flex items-center space-x-2">
            <Activity className="h-5 w-5 text-green-600" />
            <span className="font-medium text-green-800">{t('systemOperational')}</span>
            <Badge variant="outline" className="bg-green-100 text-green-800">
              {stats.systemUptime}% {t('uptime')}
            </Badge>
          </div>
        </CardContent>
      </Card>

      {/* Key Metrics */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
        >
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">{t('totalUsers')}</CardTitle>
              <Users className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.totalUsers}</div>
              <p className="text-xs text-muted-foreground">
                {stats.activeUsers} {t('activeUsers')}
              </p>
            </CardContent>
          </Card>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
        >
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">{t('totalTransactions')}</CardTitle>
              <CreditCard className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.totalTransactions}</div>
              <p className="text-xs text-muted-foreground">
                <TrendingUp className="h-3 w-3 inline mr-1" />
                {t('systemVolume')}
              </p>
            </CardContent>
          </Card>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
        >
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">{t('totalRevenue')}</CardTitle>
              <div className="flex items-center space-x-2">
                <DollarSign className="h-4 w-4 text-muted-foreground" />
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-4 w-4 p-0"
                  onClick={() => setShowRevenue(!showRevenue)}
                >
                  {showRevenue ? (
                    <Eye className="h-3 w-3" />
                  ) : (
                    <EyeOff className="h-3 w-3" />
                  )}
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {showRevenue ? formatCurrency(stats.totalRevenue) : '••••••'}
              </div>
              <p className="text-xs text-muted-foreground">
                {t('systemRevenue')}
              </p>
            </CardContent>
          </Card>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
        >
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">{t('pendingIssues')}</CardTitle>
              <AlertTriangle className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.pendingDisputes}</div>
              <p className="text-xs text-muted-foreground">
                {t('requiresAttention')}
              </p>
            </CardContent>
          </Card>
        </motion.div>
      </div>

      {/* User Distribution */}
      <Card>
        <CardHeader>
          <CardTitle>{t('userDistribution')}</CardTitle>
          <CardDescription>{t('usersByAccountType')}</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">{stats.usersByType.passengers}</div>
              <p className="text-sm text-muted-foreground">{t('passengers')}</p>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">{stats.usersByType.drivers}</div>
              <p className="text-sm text-muted-foreground">{t('drivers')}</p>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">{stats.usersByType.merchants}</div>
              <p className="text-sm text-muted-foreground">{t('merchants')}</p>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-orange-600">{stats.usersByType.eventAdmins}</div>
              <p className="text-sm text-muted-foreground">{t('eventAdmins')}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Recent Users */}
        <Card>
          <CardHeader>
            <CardTitle>{t('recentUsers')}</CardTitle>
            <CardDescription>{t('latestRegistrations')}</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {stats.recentUsers.length > 0 ? (
                stats.recentUsers.map((user, index) => (
                  <motion.div
                    key={user.id}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: index * 0.1 }}
                    className="flex items-center justify-between p-3 border rounded-lg"
                  >
                    <div className="flex-1">
                      <h4 className="font-medium">{user.full_name}</h4>
                      <p className="text-sm text-muted-foreground">{user.email}</p>
                    </div>
                    <div className="flex items-center space-x-2">
                      <Badge variant={getUserTypeColor(user.user_type)}>
                        {t(user.user_type)}
                      </Badge>
                      <Badge variant={user.is_active ? 'default' : 'secondary'}>
                        {user.is_active ? t('active') : t('inactive')}
                      </Badge>
                    </div>
                  </motion.div>
                ))
              ) : (
                <p className="text-center text-muted-foreground py-4">
                  {t('noRecentUsers')}
                </p>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Recent Transactions */}
        <Card>
          <CardHeader>
            <CardTitle>{t('recentTransactions')}</CardTitle>
            <CardDescription>{t('latestSystemActivity')}</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {stats.recentTransactions.length > 0 ? (
                stats.recentTransactions.map((transaction, index) => (
                  <motion.div
                    key={transaction.id}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: index * 0.1 }}
                    className="flex items-center justify-between p-3 border rounded-lg"
                  >
                    <div className="flex-1">
                      <h4 className="font-medium">
                        {transaction.from_profile?.full_name} → {transaction.to_profile?.full_name}
                      </h4>
                      <p className="text-sm text-muted-foreground">
                        {t(transaction.transaction_type)} • {transaction.payment_method}
                      </p>
                    </div>
                    <div className="flex items-center space-x-2">
                      <Badge variant={getTransactionStatusColor(transaction.status)}>
                        {t(transaction.status)}
                      </Badge>
                      <span className="text-sm font-medium">
                        {formatCurrency(transaction.amount)}
                      </span>
                    </div>
                  </motion.div>
                ))
              ) : (
                <p className="text-center text-muted-foreground py-4">
                  {t('noRecentTransactions')}
                </p>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions */}
      <Card>
        <CardHeader>
          <CardTitle>{t('quickActions')}</CardTitle>
          <CardDescription>{t('commonAdministrativeTasks')}</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-4">
            <Button variant="outline" className="h-auto p-4">
              <div className="flex flex-col items-center space-y-2">
                <Users className="h-6 w-6" />
                <span>{t('manageUsers')}</span>
              </div>
            </Button>
            <Button variant="outline" className="h-auto p-4">
              <div className="flex flex-col items-center space-y-2">
                <TrendingUp className="h-6 w-6" />
                <span>{t('systemAnalytics')}</span>
              </div>
            </Button>
            <Button variant="outline" className="h-auto p-4">
              <div className="flex flex-col items-center space-y-2">
                <AlertTriangle className="h-6 w-6" />
                <span>{t('handleDisputes')}</span>
              </div>
            </Button>
            <Button variant="outline" className="h-auto p-4">
              <div className="flex flex-col items-center space-y-2">
                <Settings className="h-6 w-6" />
                <span>{t('systemConfig')}</span>
              </div>
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}