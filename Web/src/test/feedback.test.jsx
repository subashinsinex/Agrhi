import { render, screen } from "@testing-library/react";
import "@testing-library/jest-dom";
import Feedback from "../components/feedback.jsx"; // note: match exact path/name

test("renders feedback heading", () => {
  render(<Feedback />);
  // Change text to something that is definitely on the page, e.g. the main title
  expect(screen.getByText(/feedback/i)).toBeInTheDocument();
});
