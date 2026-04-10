import { couriers, admins } from '@/lib/data';
import SettingsForm from './components/settings-form';

export default function SettingsPage() {
  return <SettingsForm couriers={couriers} admins={admins} />;
}
