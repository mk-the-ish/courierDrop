# DropCity Admin Dashboard

A modern, professional web app dashboard built with **Next.js 14**, **Tailwind CSS**, and **Firebase Authentication** for managing the DropCity delivery platform.

## Features

### 🔐 Authentication
- **Email/Password Login** - Secure Firebase authentication
- **Forgot Password** - Email-based password reset
- **Protected Routes** - Automatic redirection for unauthenticated users
- **Session Management** - Persistent sessions across page reloads
- **Logout** - One-click sign out from sidebar

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
- **Authentication**: Firebase Authentication
- **Icons**: Lucide React
- **HTTP Client**: Axios (built-in)
- **Forms**: React Hook Form
- **Bundler**: Next.js built-in webpack

## Project Structure

```
admin/
├── src/
│   ├── app/
│   │   ├── layout.tsx              # Root layout with AuthProvider
│   │   ├── page.tsx                # Dashboard (protected)
│   │   ├── login/page.tsx          # Login page
│   │   ├── forgot-password/page.tsx # Forgot password page
│   │   ├── reset-password/page.tsx  # Reset password page
│   │   ├── alerts/page.tsx         # Alert rules (protected)
│   │   ├── vehicles/page.tsx       # Vehicles (protected)
│   │   ├── health/page.tsx         # System health (protected)
│   │   ├── scheduler/page.tsx      # Scheduler (protected)
│   │   └── settings/page.tsx       # Settings (protected)
│   ├── components/
│   │   ├── admin-layout.tsx        # Main layout with route protection
│   │   ├── Sidebar.tsx             # Navigation with logout button
│   │   ├── protected-route.tsx     # Route protection wrapper
│   │   └── ...other components
│   ├── lib/
│   │   ├── firebase.ts             # Firebase initialization
│   │   ├── auth-context.tsx        # Auth provider & useAuth hook
│   │   └── ...other utilities
│   └── styles/
│       └── globals.css             # Tailwind + custom styles
├── .env.local.example              # Environment variable template
├── AUTH_SETUP.md                   # Complete setup guide
├── AUTH_QUICK_REFERENCE.md         # Developer reference
├── AUTHENTICATION_SUMMARY.md       # Quick overview
├── VERIFICATION_CHECKLIST.md       # Integration verification
└── IMPLEMENTATION_COMPLETE.md      # Implementation summary
```

## Quick Start

### 1. Setup Firebase
1. Create project at https://console.firebase.google.com
2. Enable Email/Password authentication
3. Copy project credentials

### 2. Configure Environment
```bash
# Copy template
cp .env.local.example .env.local

# Edit .env.local with your Firebase credentials
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
# ... see .env.local.example for all variables
```

### 3. Install & Run
```bash
npm install
npm run dev
```

Visit `http://localhost:3000/login` to sign in

### 4. Create Test User
1. Firebase Console > Authentication > Users > Add User
2. Enter test email and password
3. Login with these credentials

## Authentication Flow

### Sign In
1. User visits http://localhost:3000
2. AuthProvider checks Firebase auth state
3. If not authenticated → Redirect to `/login`
4. User enters email and password
5. Firebase verifies credentials
6. Session stored securely
7. Redirect to dashboard (`/`)

### Protected Routes
All dashboard pages require authentication:
- `/` - Dashboard
- `/alerts` - Alert Rules
- `/vehicles` - Vehicle Verification
- `/health` - System Health
- `/scheduler` - Scheduler
- `/settings` - Settings

Unauthenticated access → Auto-redirect to `/login`

### Forgot Password
1. Click "Reset it here" on login page
2. Enter email address
3. Firebase sends reset email
4. Click link in email
5. Enter new password
6. Redirected to login
7. Login with new password

### Logout
1. Click "Sign Out" button in sidebar footer
2. Session cleared
3. Redirected to `/login`

## Using Authentication in Components

```tsx
import { useAuth } from "@/lib/auth-context";

export default function MyComponent() {
  const { user, loading, signOutUser } = useAuth();

  if (loading) return <div>Loading...</div>;
  if (!user) return <div>Not logged in</div>;

  return (
    <div>
      <p>Welcome, {user.email}</p>
      <button onClick={() => signOutUser()}>Sign Out</button>
    </div>
  );
}
```

## API Integration

The dashboard connects to the backend API at `http://localhost:8080`:

- `GET /` - Health check
- `GET /health/jobs` - Job scheduler status
- `GET /health/heartbeats` - System health
- `GET /admin/alerts/rules` - Fetch alert rules
- `POST /admin/alerts/rules` - Create alert rule
- `PATCH /admin/alerts/rules/:id` - Update alert rule
- `DELETE /admin/alerts/rules/:id` - Delete alert rule

### Authentication
All API requests include Firebase ID token:
```
Authorization: Bearer <firebase_id_token>
```

The token is automatically managed by Firebase and included in requests.

## Documentation

### 📖 Setup Guide
See [AUTH_SETUP.md](./AUTH_SETUP.md) for:
- Complete Firebase project setup
- Environment configuration
- Authentication flow details
- Testing procedures
- Troubleshooting
- Production deployment

### 📖 Quick Reference
See [AUTH_QUICK_REFERENCE.md](./AUTH_QUICK_REFERENCE.md) for:
- Code examples
- Component patterns
- Error codes
- Common patterns

### 📖 Verification
See [VERIFICATION_CHECKLIST.md](./VERIFICATION_CHECKLIST.md) for:
- File structure verification
- Code integration checks
- Testing procedures
- Deployment readiness

### 📖 Summary
See [AUTHENTICATION_SUMMARY.md](./AUTHENTICATION_SUMMARY.md) for:
- Quick overview
- Getting started
- Status and features

## Configuration

### Required Environment Variables
All these must be set in `.env.local`:

```env
# Firebase
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=

# Backend API (Optional)
NEXT_PUBLIC_BACKEND_URL=http://localhost:8080
```

Copy from `.env.local.example` and fill in your values.

## Styling

The dashboard uses:
- **Color Scheme**: DropCity dark theme (slate-800/900 backgrounds, teal-600 accents)
- **Components**: Radix UI components with Tailwind CSS
- **Icons**: Lucide React icons
- **Responsive**: Mobile-first design

Custom Tailwind components in `styles/globals.css`:
- `.card` - White content cards with shadow
- `.btn-primary` - Teal primary button
- `.btn-secondary` - Gray secondary button
- `.badge` - Status badge component

## Development Notes

- Dashboard auto-refreshes metrics every 5 seconds
- All components use Tailwind CSS utility classes
- Modern, clean color palette
- Mobile-responsive design
- Error handling with user feedback
- Authentication managed by Firebase
- Protected routes via AuthProvider

## Security Best Practices

- ✅ Never commit `.env.local` to version control
- ✅ Use HTTPS in production (automatic on most platforms)
- ✅ Enable 2FA on admin account
- ✅ Regularly rotate admin passwords
- ✅ Monitor authentication in Firebase Console
- ✅ Review authorized domains periodically

## Deployment

### Build for Production
```bash
npm run build
npm start
```

### Deploy to Render/Vercel
1. Connect your git repository
2. Set environment variables on platform
3. Add production domain to Firebase Authorized Domains
4. Deploy (automatic on push)

See [AUTH_SETUP.md](./AUTH_SETUP.md) "Production Deployment" for detailed steps.

## Troubleshooting

### Common Issues
- **"Firebase app not initialized"** - Check `.env.local` file and variables
- **"Cannot sign in from this domain"** - Add domain to Firebase Authorized Domains
- **"Password reset email not received"** - Check spam folder or Firebase email settings

See [AUTH_SETUP.md](./AUTH_SETUP.md) "Troubleshooting" section for more.

## Future Enhancements

- Real-time WebSocket updates
- Advanced filtering and search
- Export data to CSV/PDF
- Audit logs
- Team management
- Custom branding

## Support

- 📘 [Firebase Authentication Docs](https://firebase.google.com/docs/auth)
- 📘 [Next.js Documentation](https://nextjs.org/docs)
- 📘 [Tailwind CSS Docs](https://tailwindcss.com/docs)
- 📘 [Radix UI Docs](https://www.radix-ui.com/)

---

**Status**: ✅ Production Ready
**Version**: 1.0.0 with Authentication
**Last Updated**: 2024

