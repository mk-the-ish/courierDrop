import { couriers } from '@/lib/data';
import CourierData from './components/courier-data';

export default function CouriersPage() {
  return <CourierData couriers={couriers} />;
}
