import React, { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useAuth } from '@/contexts/AuthContext'
import { useLanguage } from '@/contexts/LanguageContext'
import { supabase } from '@/lib/supabase'
import { toast } from 'sonner'
import { 
  QrCode, 
  Search, 
  Filter,
  CheckCircle,
  XCircle,
  Clock,
  User,
  Calendar,
  MapPin,
  Ticket,
  Scan,
  AlertCircle,
  Download
} from 'lucide-react'

interface TicketValidation {
  id: string
  ticket_code: string
  status: 'pending' | 'active' | 'used' | 'cancelled'
  event_id: string
  user_id: string
  purchase_date: string
  used_date?: string
  validation_notes?: string
  events: {
    title: string
    event_date: string
    location: string
    ticket_price: number
  }
  profiles: {
    full_name: string
    email: string
  }
}

export default function TicketValidationPage() {
  const { profile } = useAuth()
  const { t, language } = useLanguage()
  const [tickets, setTickets] = useState<TicketValidation[]>([])
  const [filteredTickets, setFilteredTickets] = useState<TicketValidation[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [eventFilter, setEventFilter] = useState('all')
  const [events, setEvents] = useState<any[]>([])
  const [scannerMode, setScannerMode] = useState(false)
  const [manualTicketCode, setManualTicketCode] = useState('')
  const [selectedTicket, setSelectedTicket] = useState<TicketValidation | null>(null)
  const [validationDialog, setValidationDialog] = useState(false)

  useEffect(() => {
    fetchEvents()
    fetchTickets()
  }, [])

  useEffect(() => {
    filterTickets()
  }, [tickets, searchQuery, statusFilter, eventFilter])

  const fetchEvents = async () => {
    if (!profile) return
    
    try {
      const { data, error } = await supabase
        .from('events')
        .select('id, title, event_date')
        .eq('created_by', profile.id)
        .order('event_date', { ascending: true })

      if (error) throw error
      setEvents(data || [])
    } catch (error) {
      console.error('Error fetching events:', error)
    }
  }

  const fetchTickets = async () => {
    if (!profile) return
    
    try {
      setIsLoading(true)
      
      const { data, error } = await supabase
        .from('user_tickets')
        .select(`
          *,
          events!inner (
            title,
            event_date,
            location,
            ticket_price,
            created_by
          ),
          profiles (
            full_name,
            email
          )
        `)
        .eq('events.created_by', profile.id)
        .order('created_at', { ascending: false })

      if (error) throw error
      setTickets(data || [])
    } catch (error) {
      console.error('Error fetching tickets:', error)
      toast.error(t('errorFetchingTickets'))
    } finally {
      setIsLoading(false)
    }
  }

  const filterTickets = () => {
    let filtered = tickets

    if (searchQuery) {
      filtered = filtered.filter(ticket =>
        ticket.ticket_code.toLowerCase().includes(searchQuery.toLowerCase()) ||
        ticket.events.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        ticket.profiles.full_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        ticket.profiles.email.toLowerCase().includes(searchQuery.toLowerCase())
      )
    }

    if (statusFilter !== 'all') {
      filtered = filtered.filter(ticket => ticket.status === statusFilter)
    }

    if (eventFilter !== 'all') {
      filtered = filtered.filter(ticket => ticket.event_id === eventFilter)
    }

    setFilteredTickets(filtered)
  }

  const handleValidateTicket = async (ticketCode: string) => {
    try {
      // Find the ticket
      const ticket = tickets.find(t => t.ticket_code === ticketCode)
      
      if (!ticket) {
        toast.error(t('ticketNotFound'))
        return
      }

      if (ticket.status === 'used') {
        toast.error(t('ticketAlreadyUsed'))
        return
      }

      if (ticket.status === 'cancelled') {
        toast.error(t('ticketCancelled'))
        return
      }

      // Check if event date has passed
      if (new Date(ticket.events.event_date) < new Date()) {
        toast.error(t('eventAlreadyEnded'))
        return
      }

      setSelectedTicket(ticket)
      setValidationDialog(true)
    } catch (error) {
      console.error('Error validating ticket:', error)
      toast.error(t('errorValidatingTicket'))
    }
  }

  const confirmValidation = async () => {
    if (!selectedTicket) return

    try {
      const { error } = await supabase
        .from('user_tickets')
        .update({
          status: 'used',
          used_date: new Date().toISOString(),
          validation_notes: 'Validated by event admin'
        })
        .eq('id', selectedTicket.id)

      if (error) throw error

      toast.success(t('ticketValidatedSuccessfully'))
      setValidationDialog(false)
      setSelectedTicket(null)
      setManualTicketCode('')
      fetchTickets()
    } catch (error) {
      console.error('Error confirming validation:', error)
      toast.error(t('errorConfirmingValidation'))
    }
  }

  const handleCancelTicket = async (ticketId: string) => {
    if (!confirm(t('confirmCancelTicket'))) return

    try {
      const { error } = await supabase
        .from('user_tickets')
        .update({ 
          status: 'cancelled',
          validation_notes: 'Cancelled by event admin'
        })
        .eq('id', ticketId)

      if (error) throw error

      toast.success(t('ticketCancelledSuccessfully'))
      fetchTickets()
    } catch (error) {
      console.error('Error cancelling ticket:', error)
      toast.error(t('errorCancellingTicket'))
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active': return 'default'
      case 'used': return 'secondary'
      case 'pending': return 'secondary'
      case 'cancelled': return 'destructive'
      default: return 'secondary'
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'active': return <CheckCircle className="h-4 w-4" />
      case 'used': return <CheckCircle className="h-4 w-4" />
      case 'pending': return <Clock className="h-4 w-4" />
      case 'cancelled': return <XCircle className="h-4 w-4" />
      default: return <Clock className="h-4 w-4" />
    }
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat(language === 'ar' ? 'ar-SY' : 'en-US', {
      style: 'currency',
      currency: 'SYP',
      minimumFractionDigits: 0
    }).format(amount)
  }

  const pendingTickets = filteredTickets.filter(t => t.status === 'pending').length
  const activeTickets = filteredTickets.filter(t => t.status === 'active').length
  const usedTickets = filteredTickets.filter(t => t.status === 'used').length
  const cancelledTickets = filteredTickets.filter(t => t.status === 'cancelled').length

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">{t('ticketValidation')}</h1>
          <p className="text-muted-foreground">{t('validateAndManageEventTickets')}</p>
        </div>
        <div className="flex space-x-2">
          <Button variant="outline">
            <Download className="h-4 w-4 mr-2" />
            {t('exportData')}
          </Button>
          <Button>
            <Scan className="h-4 w-4 mr-2" />
            {t('scanQRCode')}
          </Button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{t('pendingValidation')}</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{pendingTickets}</div>
            <p className="text-xs text-muted-foreground">{t('awaitingValidation')}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{t('activeTickets')}</CardTitle>
            <Ticket className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{activeTickets}</div>
            <p className="text-xs text-muted-foreground">{t('readyForValidation')}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{t('validatedTickets')}</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{usedTickets}</div>
            <p className="text-xs text-muted-foreground">{t('alreadyUsed')}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{t('cancelledTickets')}</CardTitle>
            <XCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{cancelledTickets}</div>
            <p className="text-xs text-muted-foreground">{t('cancelledOrRefunded')}</p>
          </CardContent>
        </Card>
      </div>

      {/* Manual Validation */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <QrCode className="h-5 w-5" />
            <span>{t('manualValidation')}</span>
          </CardTitle>
          <CardDescription>{t('enterTicketCodeManually')}</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex space-x-2">
            <Input
              placeholder={t('enterTicketCode')}
              value={manualTicketCode}
              onChange={(e) => setManualTicketCode(e.target.value)}
              onKeyPress={(e) => {
                if (e.key === 'Enter') {
                  handleValidateTicket(manualTicketCode)
                }
              }}
            />
            <Button onClick={() => handleValidateTicket(manualTicketCode)}>
              {t('validate')}
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Filters */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder={t('searchTickets')}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-9"
                />
              </div>
            </div>
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder={t('filterByStatus')} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{t('allStatuses')}</SelectItem>
                <SelectItem value="pending">{t('pending')}</SelectItem>
                <SelectItem value="active">{t('active')}</SelectItem>
                <SelectItem value="used">{t('used')}</SelectItem>
                <SelectItem value="cancelled">{t('cancelled')}</SelectItem>
              </SelectContent>
            </Select>
            <Select value={eventFilter} onValueChange={setEventFilter}>
              <SelectTrigger className="w-[200px]">
                <SelectValue placeholder={t('filterByEvent')} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{t('allEvents')}</SelectItem>
                {events.map(event => (
                  <SelectItem key={event.id} value={event.id}>
                    {event.title}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Tickets Table */}
      <Card>
        <CardHeader>
          <CardTitle>{t('ticketsList')}</CardTitle>
          <CardDescription>
            {t('totalTickets')}: {filteredTickets.length}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex items-center justify-center h-32">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
          ) : filteredTickets.length > 0 ? (
            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t('ticketCode')}</TableHead>
                    <TableHead>{t('event')}</TableHead>
                    <TableHead>{t('customer')}</TableHead>
                    <TableHead>{t('purchaseDate')}</TableHead>
                    <TableHead>{t('status')}</TableHead>
                    <TableHead className="text-right">{t('actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredTickets.map((ticket, index) => (
                    <motion.tr
                      key={ticket.id}
                      initial={{ opacity: 0, y: 20 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.1 }}
                      className="hover:bg-muted/50"
                    >
                      <TableCell>
                        <div className="font-mono text-sm">
                          {ticket.ticket_code}
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="space-y-1">
                          <p className="font-medium">{ticket.events.title}</p>
                          <div className="flex items-center space-x-1 text-sm text-muted-foreground">
                            <Calendar className="h-3 w-3" />
                            <span>
                              {new Date(ticket.events.event_date).toLocaleDateString(
                                language === 'ar' ? 'ar-SY' : 'en-US'
                              )}
                            </span>
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="space-y-1">
                          <div className="flex items-center space-x-2">
                            <User className="h-4 w-4 text-muted-foreground" />
                            <span className="font-medium">{ticket.profiles.full_name}</span>
                          </div>
                          <p className="text-sm text-muted-foreground">{ticket.profiles.email}</p>
                        </div>
                      </TableCell>
                      <TableCell>
                        {new Date(ticket.purchase_date).toLocaleDateString(
                          language === 'ar' ? 'ar-SY' : 'en-US'
                        )}
                      </TableCell>
                      <TableCell>
                        <Badge variant={getStatusColor(ticket.status)}>
                          <div className="flex items-center space-x-1">
                            {getStatusIcon(ticket.status)}
                            <span>{t(ticket.status)}</span>
                          </div>
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex items-center justify-end space-x-2">
                          {ticket.status === 'active' && (
                            <Button
                              size="sm"
                              onClick={() => handleValidateTicket(ticket.ticket_code)}
                            >
                              <CheckCircle className="h-4 w-4 mr-1" />
                              {t('validate')}
                            </Button>
                          )}
                          {(ticket.status === 'active' || ticket.status === 'pending') && (
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleCancelTicket(ticket.id)}
                            >
                              <XCircle className="h-4 w-4 mr-1" />
                              {t('cancel')}
                            </Button>
                          )}
                        </div>
                      </TableCell>
                    </motion.tr>
                  ))}
                </TableBody>
              </Table>
            </div>
          ) : (
            <div className="text-center py-8">
              <Ticket className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-lg font-medium">{t('noTicketsFound')}</h3>
              <p className="text-muted-foreground">{t('noTicketsMatchFilter')}</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Validation Confirmation Dialog */}
      <Dialog open={validationDialog} onOpenChange={setValidationDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span>{t('confirmTicketValidation')}</span>
            </DialogTitle>
            <DialogDescription>
              {t('confirmValidationDescription')}
            </DialogDescription>
          </DialogHeader>
          {selectedTicket && (
            <div className="space-y-4">
              <div className="bg-muted p-4 rounded-lg space-y-2">
                <div className="flex justify-between">
                  <span className="text-sm text-muted-foreground">{t('ticketCode')}:</span>
                  <span className="font-mono">{selectedTicket.ticket_code}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-muted-foreground">{t('event')}:</span>
                  <span>{selectedTicket.events.title}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-muted-foreground">{t('customer')}:</span>
                  <span>{selectedTicket.profiles.full_name}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-muted-foreground">{t('price')}:</span>
                  <span>{formatCurrency(selectedTicket.events.ticket_price)}</span>
                </div>
              </div>
              <div className="flex justify-end space-x-2">
                <Button variant="outline" onClick={() => setValidationDialog(false)}>
                  {t('cancel')}
                </Button>
                <Button onClick={confirmValidation}>
                  <CheckCircle className="h-4 w-4 mr-2" />
                  {t('confirmValidation')}
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}