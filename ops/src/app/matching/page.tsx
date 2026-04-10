import { matchLogs } from '@/lib/data';
import MatchLog from './components/match-log';

export default function MatchingPage() {
  return <MatchLog logs={matchLogs} />;
}
