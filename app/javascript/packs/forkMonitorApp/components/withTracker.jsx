import React, { useEffect } from "react";
import ReactGA from "react-ga";

export const withTracker = (WrappedComponent, options = {}) => {
  ReactGA.initialize(process.env['GOOGLE_ANALYTICS']);

  const trackPage = page => {
    ReactGA.set({
      page,
      ...options
    });
    ReactGA.pageview(page);
  };

  const HOC = props => {
    useEffect(() => trackPage(props.location.pathname), [
      props.location.pathname
    ]);

    return <WrappedComponent {...props} />;
  };

  return HOC;
};

export default withTracker;
