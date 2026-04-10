# DropCity Admin Dashboard

A modern, professional web app dashboard built with **Next.js 14** and **Tailwind CSS** for managing the DropCity delivery platform.

## Features

### Dashboard Overview
- Real-time system health monitoring
- API status, scheduler status, uptime metrics
- Quick system information display
- Fast action buttons for common tasks

### Alert Rules Management
- Create custom alert rules based on system metrics
- Support for multiple conditions (uptime, error rate, response time, job failures)
- Multiple notification channels (email, Slack, webhooks)
- Edit and delete rules with intuitive UI
- Enable/disable alerts

### System Health Monitoring
- Real-time job status tracking
- System health metrics and details
- Performance monitoring
- Live data refresh every 5 seconds

### Modern UI Components
- **Sidebar Navigation** - Clean dark sidebar with 5 main tabs
- **Stat Cards** - Dynamic metric display with color-coded status
- **Dashboard Header** - Consistent page headers with action buttons
- **Responsive Design** - Works on desktop and tablet

## Technology Stack

- **Frontend Framework**: Next.js 14.2.5
- **UI Library**: React 18.3.1
- **Styling**: Tailwind CSS 3.4.1
- **Icons**: Lucide React
- **HTTP Client**: Axios (built-in)
- **Bundler**: Next.js built-in webpack

## Project Structure

```
admin/
├── pages/
│   ├── index.js           # Main dashboard
│   ├── alerts.js          # Alert rules management
│   └── _app.js            # Next.js app configuration
├── components/
│   ├── Sidebar.js         # Navigation sidebar
│   ├── StatCard.js        # Metric display card
│   ├── DashboardHeader.js # Page header
│   └── Layout.js          # Shared layout wrapper
├── styles/
│   └── globals.css        # Tailwind + custom styles
├── tailwind.config.js     # Tailwind configuration
├── postcss.config.js      # PostCSS plugins
└── next.config.js         # Next.js configuration
```

## Running the Dashboard

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start development server:
   ```bash
   npm run dev
   ```

3. Open browser:
   ```
   http://localhost:3000
   ```

## API Integration

The dashboard connects to the backend API at `http://localhost:8080`:

- `GET /` - Health check
- `GET /health/jobs` - Job scheduler status
- `GET /admin/alerts/rules` - Fetch alert rules
- `POST /admin/alerts/rules` - Create alert rule
- `PATCH /admin/alerts/rules/:id` - Update alert rule
- `DELETE /admin/alerts/rules/:id` - Delete alert rule

## Configuration

Backend URL is configured in the dashboard code (default: `http://localhost:8080`)

To change it, edit the `baseUrl` variable in:
- `pages/index.js`
- `pages/alerts.js`

## Authentication

Admin token is stored in localStorage. To authenticate with the backend:

1. Get a valid Firebase ID token
2. Store it in localStorage: `localStorage.setItem('adminToken', token)`
3. The dashboard will automatically include it in API requests

## Styling

Custom Tailwind components are defined in `styles/globals.css`:
- `.card` - White content cards with shadow
- `.btn-primary` - Blue primary button
- `.btn-secondary` - Gray secondary button
- `.badge` - Status badge component

## Development Notes

- Dashboard auto-refreshes health metrics every 5 seconds
- All components use Tailwind CSS utility classes
- Modern, clean color palette (slate, blue, green, orange, red)
- Mobile-responsive design
- Error handling with user feedback

## Future Enhancements

- Real-time WebSocket updates
- Advanced filtering and search
- Export data to CSV/PDF
- Dark mode toggle
- Multi-language support
- User authentication interface

### 4. Privacy Mode
- Toggle privacy mode for specific parcels
- Geofenced progress tracking support
- Parcel-specific controls

### 5. Handshake Events
- Fetch and view handshake events by parcel ID
- Live event timeline
- Shows: timestamp, step, status

### 6. Retention Policy
- Configure handshake event retention (days)
- Run cleanup to delete old events
- Admin-only operation

### 7. System Health Monitoring
- Real-time heartbeat status from all background jobs
- Job status indicators (OK, Late, Stuck)
- Auto-refresh every 30 seconds
- Stale time tracking for each heartbeat

### 8. Parcels Overview
- Full parcel list with filtering
- Filter by status (REQUESTED, ASSIGNED, ACCEPTED, PINS_SET, IN_TRANSIT, COMPLETED)
- Filter by assignment status (assigned/unassigned)
- Shows courier assignment, priority, fragility, creation time

## Setup

```bash
cd admin
npm install
npm run dev
```

Visit `http://localhost:3000` (default Next.js dev port)

## Migration Notes

- **Old files**: `app.js`, `index.html`, `styles.css` are deprecated vanilla JS files. Next.js pages take precedence.
- **Styling**: All styling is in `styles/globals.css` managed by Next.js
- **Auth**: Currently token-based (Firebase Bearer). Future: add login UI.

## Required Backend

The admin dashboard requires these backend endpoints:
- `POST /admin/roles/set` - Set user role
- `POST /admin/roles/clear` - Clear user roles
- `POST /parcels/:id/assign` - Assign parcel to courier
- `POST /parcels/:id/privacy` - Toggle privacy mode
- `GET /parcels/:id/events` - Fetch handshake events
- `POST /admin/handshake/cleanup` - Cleanup old events
- `GET /health/heartbeats` - Get system health

All endpoints except `/health/heartbeats` require admin token.

## Future Improvements

- Add login UI (Firebase Auth)
- Live WebSocket event streaming
- Real-time parcel status updates
- Event dashboard with filtering
- Error log viewer
- System alerts (SMS/email/Slack)
